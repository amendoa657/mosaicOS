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

for _, ns in ipairs({
    "quickshell:bar", "quickshell:dock", "quickshell:sidebarRight", "quickshell:sidebarLeft",
    "quickshell:notificationPopup", "quickshell:cheatsheet", "quickshell:overview",
    "quickshell:overlay", "quickshell:session", "quickshell:island", "quickshell:mosaicWallpapers",
}) do
    hg.layer(ns, { preset = "vivo", mask_threshold = 0.3 })
end

-- Notas da ilha (Super+N e Super+Shift+N já são usados no ii)
hl.bind("SUPER + ALT + N", hl.dsp.global("quickshell:mosaicNotesToggle"), { description = "Mosaic OS: notas" })
