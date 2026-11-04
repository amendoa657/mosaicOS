-- Mosaic OS: o vidro em mosaico (precisa do hyprglass-mosaic, ~/hyprglass-mosaic).
-- Carregado pelo rules.lua só quando qsConfig == "mosaic" (scripts/mosaic-os.sh
-- troca a variável e recarrega a config); com o ii, este arquivo nem é lido.
if not hl.plugin.hyprglass then return end
local hg = hl.plugin.hyprglass

-- Vidro de mosaico: o fundo atrás dele vira quadradinhos de 14 px
hg.preset("mosaico", {
    enabled = 1,
    blur_strength = 0.12,
    refraction_strength = 1.3,
    chromatic_aberration = 0.5,
    specular_strength = 2,
    saturation = 1.35,
    mosaic_size = 14,
})

-- As camadas do shell ganham o vidro de mosaico
for _, ns in ipairs({
    "quickshell:bar", "quickshell:dock", "quickshell:sidebarRight", "quickshell:sidebarLeft",
    "quickshell:notificationPopup", "quickshell:cheatsheet", "quickshell:overview",
    "quickshell:overlay", "quickshell:session",
}) do
    hg.layer(ns, { preset = "mosaico", mask_threshold = 0.3 })
end
