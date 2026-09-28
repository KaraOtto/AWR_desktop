param(
	[string]$GameRoot = "D:\STEAM\steamapps\common\Hearts of Iron IV"
)

$ErrorActionPreference = "Stop"
$ModRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $ModRoot "gfx\interface\JAP_china_incident\map"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

public static class ChinaIncidentMapGenerator {
    // Render at 2x and let the GUI downsample to its original 470x260 size.
    // This preserves much cleaner flag emblems and state-mask edges.
    const int MapW = 940;
    const int MapH = 520;
    const int Margin = 8;

    sealed class StateData {
        public int Id;
        public HashSet<int> Provinces = new HashSet<int>();
    }

    static Bitmap ReadTga(string path) {
        byte[] b = File.ReadAllBytes(path);
        if (b[2] != 2 || (b[16] != 24 && b[16] != 32)) throw new InvalidDataException("Only uncompressed 24/32-bit TGA is supported: " + path);
        int idLen = b[0], w = b[12] | (b[13] << 8), h = b[14] | (b[15] << 8), depth = b[16] / 8;
        bool top = (b[17] & 0x20) != 0;
        int off = 18 + idLen;
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        for (int sy = 0; sy < h; sy++) {
            int y = top ? sy : h - 1 - sy;
            for (int x = 0; x < w; x++) {
                int p = off + (sy * w + x) * depth;
                int a = depth == 4 ? b[p + 3] : 255;
                bmp.SetPixel(x, y, Color.FromArgb(a, b[p + 2], b[p + 1], b[p]));
            }
        }
        return bmp;
    }

    static Bitmap ResizeFlag(Bitmap src) {
        var dst = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst)) {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.DrawImage(src, new Rectangle(0, 0, MapW, MapH));
            using (var veil = new SolidBrush(Color.FromArgb(14, 92, 80, 57))) g.FillRectangle(veil, 0, 0, MapW, MapH);
        }
        return dst;
    }

    static Bitmap RisingSun() {
        var b = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(b)) {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(Color.FromArgb(210, 196, 164));
            float cx = MapW * .69f, cy = MapH * .48f;
            using (var red = new SolidBrush(Color.FromArgb(176, 39, 31))) {
                for (int i = 0; i < 16; i++) {
                    double a0 = (i * 22.5 - 5.4) * Math.PI / 180.0;
                    double a1 = (i * 22.5 + 5.4) * Math.PI / 180.0;
                    PointF p0 = new PointF(cx + (float)Math.Cos(a0) * 1240, cy + (float)Math.Sin(a0) * 1240);
                    PointF p1 = new PointF(cx + (float)Math.Cos(a1) * 1240, cy + (float)Math.Sin(a1) * 1240);
                    g.FillPolygon(red, new[] { new PointF(cx, cy), p0, p1 });
                }
                g.FillEllipse(red, cx - 74, cy - 74, 148, 148);
            }
            using (var veil = new SolidBrush(Color.FromArgb(12, 80, 68, 48))) g.FillRectangle(veil, 0, 0, MapW, MapH);
        }
        return b;
    }

    // 1935-1953 Republic of China Army flag, used by the National
    // Revolutionary Army during the Second Sino-Japanese War.
    static Bitmap NationalRevolutionaryArmyFlag() {
        var b = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(b)) {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(Color.FromArgb(254, 0, 0));
            using (var blue = new SolidBrush(Color.FromArgb(0, 0, 149)))
                g.FillRectangle(blue, MapW / 4f, MapH / 4f, MapW / 2f, MapH / 2f);

            float cx = MapW / 2f, cy = MapH / 2f;
            float outer = MapH * .19f, inner = MapH * .112f, disk = MapH * .087f;
            using (var white = new SolidBrush(Color.FromArgb(250, 250, 247))) {
                for (int i = 0; i < 12; i++) {
                    double a = (i * 30.0 - 90.0) * Math.PI / 180.0;
                    double a0 = a - 8.0 * Math.PI / 180.0;
                    double a1 = a + 8.0 * Math.PI / 180.0;
                    PointF p0 = new PointF(cx + (float)Math.Cos(a0) * inner, cy + (float)Math.Sin(a0) * inner);
                    PointF p1 = new PointF(cx + (float)Math.Cos(a) * outer, cy + (float)Math.Sin(a) * outer);
                    PointF p2 = new PointF(cx + (float)Math.Cos(a1) * inner, cy + (float)Math.Sin(a1) * inner);
                    g.FillPolygon(white, new[] { p0, p1, p2 });
                }
                g.FillEllipse(white, cx - disk, cy - disk, disk * 2, disk * 2);
            }
            using (var veil = new SolidBrush(Color.FromArgb(8, 80, 68, 48))) g.FillRectangle(veil, 0, 0, MapW, MapH);
        }
        return b;
    }

    // 只调整 HSV 的明度值：保持色相与饱和度不变，避免军旗红偏粉或深蓝偏灰。
    // contrastFactor = 0.92 对应轻微降低约 8% 对比度；brightnessFactor = 0.97 对应亮度约 -3%。
    static void AdjustFlagTone(Bitmap bitmap, float contrastFactor, float brightnessFactor) {
        for (int y = 0; y < bitmap.Height; y++) for (int x = 0; x < bitmap.Width; x++) {
            Color c = bitmap.GetPixel(x, y);
            int max = Math.Max(c.R, Math.Max(c.G, c.B));
            if (max == 0 || c.A == 0) continue;
            float value = max / 255f;
            float adjustedValue = ((value - .5f) * contrastFactor + .5f) * brightnessFactor;
            adjustedValue = Math.Max(0f, Math.Min(1f, adjustedValue));
            float scale = adjustedValue / value;
            int r = Math.Max(0, Math.Min(255, (int)Math.Round(c.R * scale)));
            int g = Math.Max(0, Math.Min(255, (int)Math.Round(c.G * scale)));
            int bl = Math.Max(0, Math.Min(255, (int)Math.Round(c.B * scale)));
            bitmap.SetPixel(x, y, Color.FromArgb(c.A, r, g, bl));
        }
    }

    static int Key(Color c) { return c.R | (c.G << 8) | (c.B << 16); }

    public static void Generate(string gameRoot, string modRoot, string outputRoot) {
        var states = new List<StateData>();
        foreach (string file in Directory.GetFiles(Path.Combine(gameRoot, "history", "states"), "*.txt")) {
            string s = File.ReadAllText(file);
            if (!Regex.IsMatch(s, @"add_core_of\s*=\s*(CHI|PRC|TIB)")) continue;
            var idm = Regex.Match(s, @"(?m)^\s*id\s*=\s*(\d+)");
            var pm = Regex.Match(s, @"(?s)provinces\s*=\s*\{([^}]+)\}");
            if (!idm.Success || !pm.Success) continue;
            var sd = new StateData { Id = int.Parse(idm.Groups[1].Value) };
            foreach (Match m in Regex.Matches(pm.Groups[1].Value, @"\d+")) sd.Provinces.Add(int.Parse(m.Value));
            states.Add(sd);
        }

        var provinceByColor = new Dictionary<int, int>();
        foreach (string line in File.ReadLines(Path.Combine(gameRoot, "map", "definition.csv"))) {
            string[] p = line.Split(';');
            if (p.Length < 4) continue;
            int id, r, g, b;
            if (int.TryParse(p[0], out id) && int.TryParse(p[1], out r) && int.TryParse(p[2], out g) && int.TryParse(p[3], out b)) provinceByColor[r | (g << 8) | (b << 16)] = id;
        }
        var stateByProvince = new Dictionary<int, int>();
        foreach (var state in states) foreach (int p in state.Provinces) stateByProvince[p] = state.Id;

        using (var provinceMap = new Bitmap(Path.Combine(gameRoot, "map", "provinces.bmp"))) {
            int minX = provinceMap.Width, minY = provinceMap.Height, maxX = 0, maxY = 0;
            for (int y = 0; y < provinceMap.Height; y += 2) for (int x = 0; x < provinceMap.Width; x += 2) {
                int prov;
                if (provinceByColor.TryGetValue(Key(provinceMap.GetPixel(x, y)), out prov) && stateByProvince.ContainsKey(prov)) {
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y); maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                }
            }
            minX = Math.Max(0, minX - 8); minY = Math.Max(0, minY - 8); maxX = Math.Min(provinceMap.Width - 1, maxX + 8); maxY = Math.Min(provinceMap.Height - 1, maxY + 8);
            int cropW = maxX - minX + 1, cropH = maxY - minY + 1;
            double scale = Math.Min((double)MapW / cropW, (double)MapH / cropH);
            int drawW = (int)Math.Round(cropW * scale), drawH = (int)Math.Round(cropH * scale);
            int ox = (MapW - drawW) / 2, oy = (MapH - drawH) / 2;
            int[,] statePixels = new int[MapW, MapH];
            for (int y = oy; y < oy + drawH; y++) for (int x = ox; x < ox + drawW; x++) {
                int sx = minX + Math.Min(cropW - 1, (int)((x - ox) / scale));
                int sy = minY + Math.Min(cropH - 1, (int)((y - oy) / scale));
                int prov, sid;
                if (provinceByColor.TryGetValue(Key(provinceMap.GetPixel(sx, sy)), out prov) && stateByProvince.TryGetValue(prov, out sid)) statePixels[x, y] = sid;
            }

            var baseMap = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
            var borderMap = new Bitmap(MapW, MapH, PixelFormat.Format32bppArgb);
            for (int y = 0; y < MapH; y++) for (int x = 0; x < MapW; x++) if (statePixels[x, y] != 0) {
                bool edge = x == 0 || y == 0 || x == MapW - 1 || y == MapH - 1 || statePixels[Math.Max(0,x-1),y] != statePixels[x,y] || statePixels[Math.Min(MapW-1,x+1),y] != statePixels[x,y] || statePixels[x,Math.Max(0,y-1)] != statePixels[x,y] || statePixels[x,Math.Min(MapH-1,y+1)] != statePixels[x,y];
                // 中立区退到背景层：约亮度 -12%、对比度 -8%，仍保留石板灰轮廓。
                baseMap.SetPixel(x, y, edge ? Color.FromArgb(228, 43, 42, 38) : Color.FromArgb(205, 92, 91, 82));
                if (edge) borderMap.SetPixel(x, y, Color.FromArgb(238, 36, 35, 32));
            }
            baseMap.Save(Path.Combine(outputRoot, "china_incident_map_base.png"), ImageFormat.Png);
            borderMap.Save(Path.Combine(outputRoot, "china_incident_map_borders.png"), ImageFormat.Png);
            baseMap.Dispose();
            borderMap.Dispose();

            string flagsRoot = Path.Combine(gameRoot, "gfx", "flags");
            var japaneseFlag = RisingSun();
            AdjustFlagTone(japaneseFlag, .92f, .97f);
            var frameSources = new List<Bitmap> { japaneseFlag };
            var frameTags = new List<string> { "JAP" };
            frameTags.Add("CHI");
            var nationalRevolutionaryArmyFlag = NationalRevolutionaryArmyFlag();
            AdjustFlagTone(nationalRevolutionaryArmyFlag, .92f, .97f);
            frameSources.Add(nationalRevolutionaryArmyFlag);
            string[,] flagData = {
                { "PRC", "PRC_communism.tga" },
                { "GXC", "GXC_neutrality.tga" },
                { "GDC", "GDC_neutrality.tga" },
                { "YUN", "YUN_neutrality.tga" },
                { "SHX", "SHX_neutrality.tga" },
                { "XSM", "XSM_neutrality.tga" },
                { "SIK", "SIK_neutrality.tga" },
                { "MAN", "MAN_neutrality.tga" },
                { "MEN", "MEN_neutrality.tga" },
                { "RNG", "RNG_neutrality.tga" },
                { "TIB", "TIB_neutrality.tga" },
                { "GER", "GER_fascism.tga" },
                { "ITA", "ITA_fascism.tga" },
                { "SOV", "SOV_communism.tga" },
                { "ENG", "ENG_democratic.tga" },
                { "USA", "USA_democratic.tga" },
                { "FRA", "FRA_democratic.tga" }
            };
            for (int i = 0; i < flagData.GetLength(0); i++) {
                frameTags.Add(flagData[i, 0]);
                using (var raw = ReadTga(Path.Combine(flagsRoot, flagData[i, 1]))) frameSources.Add(ResizeFlag(raw));
            }
            File.WriteAllLines(Path.Combine(outputRoot, "flag_manifest.csv"), frameTags.Select((tag, index) => tag + ";" + (index + 1)));

            var manifest = new List<string>();
            foreach (var state in states.OrderBy(s => s.Id)) {
                int bx0 = MapW, by0 = MapH, bx1 = -1, by1 = -1;
                for (int y = 0; y < MapH; y++) for (int x = 0; x < MapW; x++) if (statePixels[x, y] == state.Id) { bx0 = Math.Min(bx0,x); by0 = Math.Min(by0,y); bx1 = Math.Max(bx1,x); by1 = Math.Max(by1,y); }
                if (bx1 < 0) continue;
                bx0 = Math.Max(0, bx0 - Margin); by0 = Math.Max(0, by0 - Margin); bx1 = Math.Min(MapW - 1, bx1 + Margin); by1 = Math.Min(MapH - 1, by1 + Margin);
                // Keep crop origins and dimensions divisible by two so every
                // state aligns exactly after the GUI applies scale = 0.5.
                bx0 -= bx0 % 2; by0 -= by0 % 2;
                if (bx1 % 2 == 0 && bx1 < MapW - 1) bx1++;
                if (by1 % 2 == 0 && by1 < MapH - 1) by1++;
                int w = bx1 - bx0 + 1, h = by1 - by0 + 1;
                var atlas = new Bitmap(w * frameSources.Count, h, PixelFormat.Format32bppArgb);
                for (int fi = 0; fi < frameSources.Count; fi++) for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                    int mx = bx0 + x, my = by0 + y;
                    if (statePixels[mx, my] == state.Id) atlas.SetPixel(fi * w + x, y, frameSources[fi].GetPixel(mx, my));
                }
                string name = "state_" + state.Id + ".png";
                atlas.Save(Path.Combine(outputRoot, name), ImageFormat.Png);
                atlas.Dispose();
                manifest.Add(state.Id + ";" + bx0 + ";" + by0 + ";" + w + ";" + h);
            }
            foreach (var b in frameSources) b.Dispose();
            File.WriteAllLines(Path.Combine(outputRoot, "map_manifest.csv"), manifest);
        }
    }
}
'@ -ReferencedAssemblies System.Drawing

[ChinaIncidentMapGenerator]::Generate($GameRoot, $ModRoot, $OutputRoot)
Write-Host "China Incident map assets written to $OutputRoot"
