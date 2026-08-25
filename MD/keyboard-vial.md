# Teclado Avalanche — remapeamento com Vial

## O teclado

**vitvlkv Avalanche**, split ergonômico, USB `cee2:0004`. O firmware é **Vial**, um fork do
QMK que permite remapear ao vivo, sem recompilar nem regravar.

A prova está no próprio dispositivo, e serve para identificar qualquer teclado desconhecido:

```bash
for d in /sys/class/input/input*/; do
  n=$(cat $d/name 2>/dev/null)
  case "$n" in *Avalanche*) echo "$n uniq=$(cat $d/uniq 2>/dev/null)";; esac
done
# vitvlkv Avalanche  uniq=vial:f64c2b3c
```

O `uniq` começando com `vial:` é a assinatura do firmware. Num teclado QMK puro esse campo
vem vazio.

## Onde configurar

**https://vial.rocks** — roda no Chrome via WebHID, não instala nada. É o caminho mais curto.

Alternativa local, se preferir app: `paru -S vial-appimage` (AUR, pacote `vial-appimage`).

## A regra de udev é obrigatória

O Vial fala **HID cru**, não evdev. Sem a regra abaixo, nem o site nem o app enxergam o
teclado — e o sintoma é uma lista de dispositivos vazia, sem mensagem de erro:

```bash
echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"' \
  | sudo tee /etc/udev/rules.d/92-viia.rules \
  && sudo udevadm control --reload && sudo udevadm trigger
```

Depois, reconecte o teclado uma vez.

## Tecla que apaga a tela

O Avalanche expõe **quatro** endpoints além do teclado principal:

| endpoint | nó | o que manda |
|---|---|---|
| Keyboard | event6 | teclas normais |
| Mouse | event3 | movimento e cliques |
| Consumer Control | event5 | mídia: volume, play, pause |
| **System Control** | **event4** | **`KC_SYSTEM_SLEEP`, `KC_SYSTEM_POWER`, `KC_SYSTEM_WAKE`** |

Se alguma combinação apagar ou suspender a tela, o suspeito é o **System Control** — não o
compositor. No mapa do Vial ela aparece como *System Sleep* ou *System Power Down*.

Para descobrir qual tecla é, antes de caçar no mapa, monitore o nó enquanto aperta:

```bash
sudo evtest /dev/input/event4
```

**Não há bind de lock no Hyprland** (`~/.config/hypr/hyprland.conf`). O único bind que mexe
em tela é `$mainMod + F10`, que alterna o DPMS do `DP-2` — ver [hyprland-crashes](hyprland-crashes.md).
Então comando que apaga a tela sem passar por ali veio do teclado.

## Cuidado com endpoints de teclado em outros dispositivos

O mesmo padrão mordeu com um controle 8BitDo: ele expõe um endpoint de **Keyboard** que fez o
systemd-logind tratá-lo como teclado e disparar *Secure Attention Key*, abrindo greeters do
SDDM que sequestraram o display `:1`. Sempre que um periférico "estranho" mexer na sessão,
liste os endpoints dele antes de culpar o compositor.
