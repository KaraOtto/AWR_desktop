param(
	[string]$GameRoot = "D:\STEAM\steamapps\common\Hearts of Iron IV"
)

$ErrorActionPreference = "Stop"
$ModRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $ModRoot "gfx\interface\JAP_pacific\map"
$SourceRoot = Join-Path $ModRoot "art_source\JAP_pacific"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

public static class JapPacificMapGenerator {
    const int MapW = 1000;
    const int MapH = 520;
    const int NorthernSourceStartX = 4800;
    const int SouthernSourceStartX = 3950;
    const int SourceEndWrappedX = 1000;
    // Shift the viewport south so Taiwan and the full Southeast Asian theatre
    // remain inside the decision map instead of deleting mainland geography.
    const int SourceTopY = 300;
    const int SourceBottomY = 1960;
    const int MaskMargin = 8;

    sealed class StateData {
        public int Id;
        public HashSet<int> Provinces = new HashSet<int>();
        public bool IsChinaCore;
    }

    static readonly int[] StrategicStates = {
        282, 528, 529, 530, 531, 532, 533, 534, 535, 536, 1018, 1019, 1020,
        524, 526, 645,
        336, 1021, 1060, 1061, 1062, 1063, 1064, 1065,
        327, 623, 624, 625, 626, 627, 628, 1025, 1026, 1027,
        334, 335, 667, 668, 669, 672, 673, 1047, 1048, 1049, 1050, 1051,
        1052, 1053, 1054, 1055, 1056, 1057, 1058,
        523, 634, 638, 639, 646, 979, 1070, 1073,
        629, 631, 632, 378, 385, 386
    };

    static readonly Dictionary<string, int[]> RegionStates = new Dictionary<string, int[]> {
        { "japan", new[] { 282,528,529,530,531,532,533,534,535,536,1018,1019,1020 } },
        { "taiwan", new[] { 524 } },
        { "malaya", new[] { 336,1060,1061,1062,1063,1064,1065 } },
        { "singapore", new[] { 1021 } },
        { "philippines", new[] { 327,623,624,625,626,627,628,1025,1026,1027 } },
        { "dei", new[] { 334,335,667,668,669,672,673,1047,1048,1049,1050,1051,1052,1053,1054,1055,1056,1057,1058 } },
        { "marianas", new[] { 638,639,646 } },
        { "new_guinea", new[] { 523,634,669,979,1057,1070,1073 } },
        { "wake", new[] { 632 } },
        { "midway", new[] { 631 } },
        { "hawaii", new[] { 629 } },
        { "iwo_jima", new[] { 645 } },
        { "okinawa", new[] { 526 } },
        { "west_coast", new[] { 378,385,386 } }
        ,{ "rabaul", new[] { 737 } }
        ,{ "carolines", new[] { 684 } }
        ,{ "palau", new[] { 647 } }
        ,{ "marshalls", new[] { 633 } }
        ,{ "gilberts", new[] { 639 } }
        ,{ "solomons", new[] { 634 } }
        ,{ "new_caledonia", new[] { 635 } }
        ,{ "fiji", new[] { 636 } }
        ,{ "samoa", new[] { 726,1072 } }
    };

    // These states are only enlarged as geographical reference. They do not
    // receive new control triggers, isolation checks or strategic scoring.
    static readonly int[] GeographicIslandStates = {
        526, 645, 638, 646, 684, 647, 633, 639, 632, 631, 629,
        737, 634, 635, 636, 726, 1072
    };

    static int Key(Color c) { return c.R | (c.G << 8) | (c.B << 16); }

    static int WrappedSourceX(int x, int y, int sourceWidth) {
        // A restrained latitude-dependent crop keeps Burma and Indochina in
        // the southern theatre while compressing inland China at the north.
        int sy = SourceY(y);
        double southernBlend = Math.Max(0.0, Math.Min(1.0, (sy - 760.0) / 520.0));
        int sourceStartX = (int)Math.Round(NorthernSourceStartX + (SouthernSourceStartX - NorthernSourceStartX) * southernBlend);
        int cropWidth = (sourceWidth - sourceStartX) + SourceEndWrappedX;
        int sx = sourceStartX + (int)Math.Floor((x + .5) * cropWidth / MapW);
        return sx >= sourceWidth ? sx - sourceWidth : sx;
    }

    static int SourceY(int y) {
        return SourceTopY + (int)Math.Floor((y + .5) * (SourceBottomY - SourceTopY) / MapH);
    }

    static Color RisingSunPixel(int x, int y, Rectangle bounds) {
        double u = (x - bounds.Left) / Math.Max(1.0, bounds.Width - 1.0);
        double v = (y - bounds.Top) / Math.Max(1.0, bounds.Height - 1.0);
        double dx = u - .47, dy = v - .50;
        double radius = Math.Sqrt(dx*dx + dy*dy);
        double angle = Math.Atan2(dy, dx);
        double ray = Math.Cos(angle * 8.0);
        bool red = radius < .19 || (ray > .23 && radius < .85);
        return red ? Color.FromArgb(226, 126, 39, 35) : Color.FromArgb(226, 194, 184, 158);
    }

    static Color UnitedStatesPixel(int x, int y, Rectangle bounds) {
        double u = (x - bounds.Left) / Math.Max(1.0, bounds.Width - 1.0);
        double v = (y - bounds.Top) / Math.Max(1.0, bounds.Height - 1.0);
        if (u < .48 && v < 7.0/13.0) {
            int starX = (int)Math.Floor(u * 20.0), starY = (int)Math.Floor(v * 24.0);
            bool star = ((starX + starY) % 4 == 0);
            return star ? Color.FromArgb(226, 190, 183, 158) : Color.FromArgb(226, 45, 61, 76);
        }
        int stripe = Math.Max(0, Math.Min(12, (int)Math.Floor(v * 13.0)));
        return (stripe % 2 == 0) ? Color.FromArgb(226, 116, 45, 43) : Color.FromArgb(226, 194, 184, 158);
    }

    static void DrawPaperGrid(Bitmap map) {
        using (Graphics g = Graphics.FromImage(map)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (var major = new Pen(Color.FromArgb(35, 187, 181, 159), 1f)) {
                for (int x = 0; x < MapW; x += 125) g.DrawLine(major, x, 0, x, MapH);
                for (int y = 0; y < MapH; y += 104) g.DrawLine(major, 0, y, MapW, y);
            }
            using (var frame = new Pen(Color.FromArgb(210, 31, 31, 29), 4f))
                g.DrawRectangle(frame, 2, 2, MapW - 5, MapH - 5);
            using (var inner = new Pen(Color.FromArgb(150, 149, 140, 119), 1f))
                g.DrawRectangle(inner, 8, 8, MapW - 17, MapH - 17);
        }
    }

    static Bitmap ResizeFlag(string path) {
        using (var src = new Bitmap(path)) {
            int minX = src.Width, minY = src.Height, maxX = -1, maxY = -1;
            for (int y = 0; y < src.Height; y += 2) for (int x = 0; x < src.Width; x += 2) {
                if (src.GetPixel(x, y).A > 8) {
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                    maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                }
            }
            if (maxX < 0) throw new InvalidDataException("Flag source has no alpha content: " + path);
            minX = Math.Max(0, minX - 8); minY = Math.Max(0, minY - 8);
            maxX = Math.Min(src.Width - 1, maxX + 8); maxY = Math.Min(src.Height - 1, maxY + 8);
            const int flagSize = 84;
            var dst = new Bitmap(flagSize, flagSize, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(dst)) {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.SmoothingMode = SmoothingMode.HighQuality;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                float scale = Math.Min(78f / (maxX - minX + 1), 78f / (maxY - minY + 1));
                int w = (int)Math.Round((maxX - minX + 1) * scale);
                int h = (int)Math.Round((maxY - minY + 1) * scale);
                g.DrawImage(src, new Rectangle((flagSize - w) / 2, flagSize - h - 4, w, h), new Rectangle(minX, minY, maxX-minX+1, maxY-minY+1), GraphicsUnit.Pixel);
            }
            return dst;
        }
    }

    static void DrawHandArrow(string path, Point a, Point b) {
        var bmp = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            PointF p0 = a, p3 = b;
            float dx = p3.X - p0.X, dy = p3.Y - p0.Y;
            PointF p1 = new PointF(p0.X + dx * .34f - dy * .12f, p0.Y + dy * .34f + dx * .12f);
            PointF p2 = new PointF(p0.X + dx * .68f - dy * .08f, p0.Y + dy * .68f + dx * .08f);
            using (var shadow = new Pen(Color.FromArgb(85, 20, 17, 14), 9f)) {
                shadow.StartCap = LineCap.Round; shadow.EndCap = LineCap.Round;
                g.DrawBezier(shadow, p0, p1, p2, p3);
            }
            using (var pen = new Pen(Color.FromArgb(218, 117, 42, 35), 5f)) {
                pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                g.DrawBezier(pen, p0, p1, p2, p3);
            }
            double angle = Math.Atan2(p3.Y - p2.Y, p3.X - p2.X);
            PointF l = new PointF(p3.X - (float)Math.Cos(angle - .58) * 27, p3.Y - (float)Math.Sin(angle - .58) * 27);
            PointF r = new PointF(p3.X - (float)Math.Cos(angle + .58) * 27, p3.Y - (float)Math.Sin(angle + .58) * 27);
            using (var brush = new SolidBrush(Color.FromArgb(225, 117, 42, 35)))
                g.FillPolygon(brush, new[] { p3, l, r });
        }
        bmp.Save(path, ImageFormat.Png);
        bmp.Dispose();
    }

    static void DrawIsolationRing(string path, Point center, int radius) {
        var bmp = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (var shadow = new Pen(Color.FromArgb(135, 13, 14, 15), 10f)) {
                shadow.DashPattern = new float[] { 2.1f, 1.4f };
                g.DrawEllipse(shadow, center.X-radius, center.Y-radius, radius*2, radius*2);
            }
            using (var pen = new Pen(Color.FromArgb(225, 74, 76, 76), 5f)) {
                pen.DashPattern = new float[] { 2.1f, 1.4f };
                g.DrawEllipse(pen, center.X-radius, center.Y-radius, radius*2, radius*2);
            }
        }
        bmp.Save(path, ImageFormat.Png);
        bmp.Dispose();
    }

    public static void Generate(string gameRoot, string sourceRoot, string outputRoot) {
        var states = new Dictionary<int, StateData>();
        foreach (string file in Directory.GetFiles(Path.Combine(gameRoot, "history", "states"), "*.txt")) {
            string s = File.ReadAllText(file);
            var idm = Regex.Match(s, @"(?m)^\s*id\s*=\s*(\d+)");
            var pm = Regex.Match(s, @"(?s)provinces\s*=\s*\{([^}]+)\}");
            if (!idm.Success || !pm.Success) continue;
            var sd = new StateData { Id = int.Parse(idm.Groups[1].Value) };
            foreach (Match m in Regex.Matches(pm.Groups[1].Value, @"\d+")) sd.Provinces.Add(int.Parse(m.Value));
            sd.IsChinaCore = Regex.IsMatch(s, @"(?m)^\s*add_core_of\s*=\s*(CHI|PRC|XSM|GXC|YUN|SHX|SIK|TIB)\s*$");
            states[sd.Id] = sd;
        }

        var provinceByColor = new Dictionary<int, int>();
        var provinceIsLand = new Dictionary<int, bool>();
        foreach (string line in File.ReadLines(Path.Combine(gameRoot, "map", "definition.csv"))) {
            string[] p = line.Split(';');
            int id, r, g, b;
            if (p.Length >= 5 && int.TryParse(p[0], out id) && int.TryParse(p[1], out r) && int.TryParse(p[2], out g) && int.TryParse(p[3], out b)) {
                provinceByColor[r | (g << 8) | (b << 16)] = id;
                provinceIsLand[id] = string.Equals(p[4], "land", StringComparison.OrdinalIgnoreCase);
            }
        }
        var stateByProvince = new Dictionary<int, int>();
        foreach (var state in states.Values) foreach (int p in state.Provinces) stateByProvince[p] = state.Id;

        using (var provinceMap = new Bitmap(Path.Combine(gameRoot, "map", "provinces.bmp"))) {
            int[,] statePixels = new int[MapW, MapH];
            bool[,] landPixels = new bool[MapW, MapH];
            var strategic = new HashSet<int>(StrategicStates);
            var random = new Random(19411207);
            var baseMap = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
            var borders = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
            var geographicAnchors = new Dictionary<int, Point>();

            for (int y = 0; y < MapH; y++) for (int x = 0; x < MapW; x++) {
                int prov, sid;
                int sx = WrappedSourceX(x, y, provinceMap.Width), sy = SourceY(y);
                if (provinceByColor.TryGetValue(Key(provinceMap.GetPixel(sx, sy)), out prov)) {
                    bool land;
                    landPixels[x,y] = provinceIsLand.TryGetValue(prov, out land) && land;
                    if (stateByProvince.TryGetValue(prov, out sid)) statePixels[x,y] = sid;
                }
                int noise = random.Next(-3, 4);
                Color c = landPixels[x,y]
                    ? (strategic.Contains(statePixels[x,y]) ? Color.FromArgb(240, 92+noise, 89+noise, 79+noise) : Color.FromArgb(232, 76+noise, 76+noise, 72+noise))
                    : Color.FromArgb(244, 41+noise, 47+noise, 52+noise);
                baseMap.SetPixel(x, y, c);
            }

            for (int y = 1; y < MapH-1; y++) for (int x = 1; x < MapW-1; x++) {
                bool coast = landPixels[x,y] != landPixels[x-1,y] || landPixels[x,y] != landPixels[x+1,y] || landPixels[x,y] != landPixels[x,y-1] || landPixels[x,y] != landPixels[x,y+1];
                bool stateEdge = landPixels[x,y] && (statePixels[x,y] != statePixels[x-1,y] || statePixels[x,y] != statePixels[x+1,y] || statePixels[x,y] != statePixels[x,y-1] || statePixels[x,y] != statePixels[x,y+1]);
                if (coast) borders.SetPixel(x,y,Color.FromArgb(245,30,30,28));
                else if (stateEdge) {
                    StateData edgeState;
                    bool chinaInterior = states.TryGetValue(statePixels[x,y], out edgeState) && edgeState.IsChinaCore;
                    borders.SetPixel(x,y, chinaInterior ? Color.FromArgb(80,47,46,42) : Color.FromArgb(215,47,46,42));
                }
            }

            // Give selected island chains a small cartographic exaggeration so
            // they survive the 50% GUI scale. This is a static visual layer;
            // it deliberately creates no per-island gameplay or daily checks.
            using (Graphics landInk = Graphics.FromImage(baseMap))
            using (Graphics coastInk = Graphics.FromImage(borders))
            using (var islandFill = new SolidBrush(Color.FromArgb(238, 88, 84, 75)))
            using (var islandEdge = new Pen(Color.FromArgb(235, 30, 30, 28), 2f)) {
                landInk.SmoothingMode = SmoothingMode.AntiAlias;
                coastInk.SmoothingMode = SmoothingMode.AntiAlias;
                foreach (int id in GeographicIslandStates) {
                    long sumX=0, sumY=0, count=0;
                    for (int y=0; y<MapH; y++) for (int x=0; x<MapW; x++) if (statePixels[x,y]==id) { sumX+=x; sumY+=y; count++; }
                    if (count==0) continue;
                    int meanX=(int)(sumX/count), meanY=(int)(sumY/count), bestX=meanX, bestY=meanY, bestDistance=int.MaxValue;
                    for (int y=0; y<MapH; y++) for (int x=0; x<MapW; x++) if (statePixels[x,y]==id) {
                        int dx=x-meanX, dy=y-meanY, distance=dx*dx+dy*dy;
                        if (distance<bestDistance) { bestDistance=distance; bestX=x; bestY=y; }
                    }
                    int radius = (id==629 || id==633 || id==634 || id==684) ? 6 : 4;
                    geographicAnchors[id] = new Point(bestX,bestY);
                    landInk.FillEllipse(islandFill,bestX-radius,bestY-radius,radius*2+1,radius*2+1);
                    coastInk.DrawEllipse(islandEdge,bestX-radius,bestY-radius,radius*2+1,radius*2+1);
                }
            }
            DrawPaperGrid(baseMap);
            baseMap.Save(Path.Combine(outputRoot, "pacific_map_base.png"), ImageFormat.Png);
            borders.Save(Path.Combine(outputRoot, "pacific_map_borders.png"), ImageFormat.Png);
            baseMap.Dispose(); borders.Dispose();

            var centers = new Dictionary<string, Point>();
            var regionBounds = new Dictionary<string, Rectangle>();
            var regionManifest = new List<string>();
            foreach (var region in RegionStates) {
                var ids = new HashSet<int>(region.Value);
                long sumX = 0, sumY = 0, count = 0;
                for (int y = 0; y < MapH; y++) for (int x = 0; x < MapW; x++) if (ids.Contains(statePixels[x,y])) {
                    sumX += x; sumY += y; count++;
                }
                if (count == 0) throw new InvalidDataException("No rendered pixels for region " + region.Key);
                int meanX = (int)(sumX/count), meanY = (int)(sumY/count);
                int minX=MapW, minY=MapH, maxX=-1, maxY=-1;
                int bestX = meanX, bestY = meanY, bestDistance = int.MaxValue;
                // Snap the visual anchor back onto an actual state pixel.  The
                // arithmetic centre of an island chain often falls in open sea.
                for (int y = 0; y < MapH; y++) for (int x = 0; x < MapW; x++) if (ids.Contains(statePixels[x,y])) {
                    minX=Math.Min(minX,x); minY=Math.Min(minY,y); maxX=Math.Max(maxX,x); maxY=Math.Max(maxY,y);
                    int dx=x-meanX, dy=y-meanY, distance=dx*dx+dy*dy;
                    if (distance < bestDistance) { bestDistance=distance; bestX=x; bestY=y; }
                }
                var center = new Point(bestX, bestY);
                centers[region.Key] = center;
                regionBounds[region.Key] = Rectangle.FromLTRB(minX,minY,maxX+1,maxY+1);
                regionManifest.Add(region.Key + ";" + center.X + ";" + center.Y + ";" + string.Join(",", region.Value));
            }
            File.WriteAllLines(Path.Combine(outputRoot, "region_manifest.csv"), regionManifest);

            var stateManifest = new List<string>();
            foreach (int id in StrategicStates.Distinct().OrderBy(v => v)) {
                int bx0=MapW, by0=MapH, bx1=-1, by1=-1;
                for (int y=0; y<MapH; y++) for (int x=0; x<MapW; x++) if (statePixels[x,y]==id) {
                    bx0=Math.Min(bx0,x); by0=Math.Min(by0,y); bx1=Math.Max(bx1,x); by1=Math.Max(by1,y);
                }
                if (bx1 < 0) continue;
                bx0=Math.Max(0,bx0-MaskMargin); by0=Math.Max(0,by0-MaskMargin);
                bx1=Math.Min(MapW-1,bx1+MaskMargin); by1=Math.Min(MapH-1,by1+MaskMargin);
                if ((bx0 & 1) == 1) bx0--; if ((by0 & 1) == 1) by0--;
                if ((bx1 & 1) == 0 && bx1 < MapW-1) bx1++; if ((by1 & 1) == 0 && by1 < MapH-1) by1++;
                int w=bx1-bx0+1, h=by1-by0+1;
                var atlas = new Bitmap(w*2,h,PixelFormat.Format32bppArgb);
                Color jap=Color.FromArgb(226,116,48,43), usa=Color.FromArgb(226,65,82,96);
                bool japanHome = RegionStates["japan"].Contains(id);
                bool usaHome = RegionStates["west_coast"].Contains(id);
                for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
                    int gx=bx0+x, gy=by0+y;
                    bool enlargedIsland = false;
                    Point islandAnchor;
                    if (geographicAnchors.TryGetValue(id,out islandAnchor)) {
                        int radius=(id==629 || id==633 || id==634 || id==684) ? 6 : 4;
                        int dx=gx-islandAnchor.X, dy=gy-islandAnchor.Y;
                        enlargedIsland=dx*dx+dy*dy<=radius*radius;
                    }
                    if (statePixels[gx,gy]!=id && !enlargedIsland) continue;
                    Color japPixel = (japanHome || usaHome) ? RisingSunPixel(gx,gy,japanHome ? regionBounds["japan"] : regionBounds["west_coast"]) : jap;
                    Color usaPixel = (japanHome || usaHome) ? UnitedStatesPixel(gx,gy,japanHome ? regionBounds["japan"] : regionBounds["west_coast"]) : usa;
                    atlas.SetPixel(x,y,japPixel); atlas.SetPixel(w+x,y,usaPixel);
                }
                atlas.Save(Path.Combine(outputRoot,"state_"+id+".png"),ImageFormat.Png);
                atlas.Dispose();
                stateManifest.Add(id+";"+bx0+";"+by0+";"+w+";"+h);
            }
            File.WriteAllLines(Path.Combine(outputRoot,"state_manifest.csv"),stateManifest);

            using (var japFlag=ResizeFlag(Path.Combine(sourceRoot,"pacific_flag_JAP_master.png"))) japFlag.Save(Path.Combine(outputRoot,"pacific_flag_JAP.png"),ImageFormat.Png);
            using (var usaFlag=ResizeFlag(Path.Combine(sourceRoot,"pacific_flag_USA_master.png"))) usaFlag.Save(Path.Combine(outputRoot,"pacific_flag_USA.png"),ImageFormat.Png);

            DrawHandArrow(Path.Combine(outputRoot,"arrow_north_1.png"),centers["japan"],centers["marianas"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_north_2.png"),centers["marianas"],centers["wake"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_north_3.png"),centers["wake"],centers["midway"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_north_4.png"),centers["midway"],centers["hawaii"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_south_1.png"),new Point(centers["malaya"].X-35,centers["malaya"].Y-80),centers["malaya"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_south_2.png"),centers["malaya"],centers["singapore"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_east_1.png"),centers["taiwan"],centers["philippines"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_east_2.png"),centers["philippines"],centers["dei"]);
            DrawHandArrow(Path.Combine(outputRoot,"arrow_rabaul_1.png"),centers["rabaul"],centers["solomons"]);

            foreach (string key in new[] { "philippines","marianas","new_guinea","wake","midway","hawaii","iwo_jima","okinawa" })
                DrawIsolationRing(Path.Combine(outputRoot,"isolation_"+key+".png"),centers[key], key=="philippines"||key=="new_guinea" ? 42 : 27);
        }
    }
}
'@ -ReferencedAssemblies System.Drawing

[JapPacificMapGenerator]::Generate($GameRoot, $SourceRoot, $OutputRoot)
Write-Host "Pacific strategy map assets written to $OutputRoot"
