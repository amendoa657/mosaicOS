-- Mosaic OS: o liquid glass dele (precisa do hyprglass; o fork ~/hyprglass-mosaic
-- serve igual). Carregado pelo rules.lua só quando qsConfig == "mosaic"; com o ii,
-- este arquivo nem é lido e vale o preset "clear" do rules.lua.
--
-- Arquivado (04/11/2026): o vidro em mosaico (mosaic_size = 14). O usuário não
-- gostou; para voltar a testar, ponha mosaic_size no preset abaixo.
if not hl.plugin.hyprglass then return end
local hg = hl.plugin.hyprglass

-- "vivo": mais lente nas bordas, refração, arco-íris e brilho que o "clear" do ii
hg.preset("vivo", {
    enabled = 1,
    blur_strength = 0.35,
    refraction_strength = 2.2,
    lens_distortion = 0.6,
    chromatic_aberration = 0.9,
    fresnel_strength = 1.2,
    specular_strength = 2.6,
    saturation = 1.45,
    vibrancy = 0.4,
    edge_thickness = 0.08,
})

-- the dock: liquid glass turned way up (strong lens, refraction, rainbow edges and shine)
hg.preset("dock", {
    enabled = 1,
    blur_strength = 0.22,
    refraction_strength = 4.8,
    lens_distortion = 1.35,
    chromatic_aberration = 1.9,
    fresnel_strength = 2.4,
    specular_strength = 4.2,
    saturation = 1.75,
    vibrancy = 0.75,
    edge_thickness = 0.16,
})

for _, ns in ipairs({
    "quickshell:bar", "quickshell:sidebarRight", "quickshell:sidebarLeft",
    "quickshell:notificationPopup", "quickshell:cheatsheet", "quickshell:overview",
    "quickshell:overlay", "quickshell:session", "quickshell:island", "quickshell:mosaicWallpapers",
}) do
    hg.layer(ns, { preset = "vivo", mask_threshold = 0.3 })
end
-- the dock's glass shows wherever its pane is even a little opaque
hg.layer("quickshell:dock", { preset = "dock", mask_threshold = 0.12 })

-- the widgets' and the dock's glass, written by the Ilha, Aparência and Dock tabs (~/.config/mosaic-os/glass.lua)
do
    local f = os.getenv("HOME") .. "/.config/mosaic-os/glass.lua"
    local fh = io.open(f, "r")
    if fh then fh:close(); dofile(f) end
end

-- Notas da ilha (Super+N e Super+Shift+N já são usados no ii)
hl.bind("SUPER + ALT + N", hl.dsp.global("quickshell:mosaicNotesToggle"), { description = "Mosaic OS: notas" })
