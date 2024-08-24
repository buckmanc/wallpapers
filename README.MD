<!--
make sure you're editing the template, doofus
-->

![desktop wallpapers](.internals/headers/desktop.png)

# 2,768 Wallpapers

A simple repo to house my wallpapers for ease of use and automation.

![mobile wallpapers](.internals/headers/mobile.png)

# Table of Contents
- [mobile](/mobile/README.MD) - 1,871
- [desktop](/desktop/README.MD) - 570
- [floaters](/floaters/README.MD) - 251
- [terminal](/terminal/README.MD) - 76

![floaters wallpapers](.internals/headers/floaters.png)

# Usage

## Nab Individual Wallpapers

Long press / right click > save link. Just don't save the thumbnail by mistake!

## Shallow Clone

If using Git, I recommend making a shallow clone of this repo to pull only the current images and not the full history. A shallow [update script](update.sh) is included for ease of use and scheduling.

To make a simple shallow clone:
```shell
git clone --depth 1 https://github.com/buckmanc/wallpapers
```

Or to clone only the directories you want in a shallow fashion (for example, to ignore the 3.0G mobile folder):
```shell
# shallow clone but download and checkout bupkis
git clone --filter=blob:none --no-checkout --depth 1 https://github.com/buckmanc/wallpapers

# set git to only clone these folders
git sparse-checkout set ./desktop ./terminal ./scripts

# download and checkout
git checkout main

```

![terminal wallpapers](.internals/headers/terminal.png)

# Attribution

I've added attribution where I can. Feel free to contact me or submit a pull request to add missing attribution.

# Aesthetic Decisions

- **Desktop/homescreen: chill**
  - Calming, spacious designs to underly busy windows and icons
- **Lockscreen: exciting**
  - Anything goes
  - Better with a neat and tidy lock screen
- **Floaters**
  - To be centered on the screen
  - Usually t-shirt designs
- **Terminal: elegant and subdued**
  - Extremely simple, standardized designs on the opposite side from the text

# Shoutouts

Thanks to [jonascarpay](https://github.com/jonascarpay/wallpapers), [makccr](https://github.com/makccr/wallpapers), and [dharmx](https://github.com/dharmx/walls) for excellent examples of wallpaper repos, all the artists of various kinds for their work, and you as Mega Man X!
