###Pre:

**hdaInjector.sh** originally maintain by [@theracermaster](https://github.com/theracermaster) for [Gigabyte-GA-Z77X-DSDT-Patch](https://github.com/theracermaster/Gigabyte-GA-Z77X-DSDT-Patch) with [@toleda](https://github.com/toleda), [@Mirone](https://github.com/Mirone), [@Piker-Alpha](https://github.com/Piker-Alpha) etc helps.

###Mods:

This mods specifically made for ALC892 & El Capitan ATM with HD4000 HDMI audio support.

###Requirements:

- El Capitan (10.11)
- Working hacks with [Clover EFI-bootloader](http://sourceforge.net/projects/cloverefiboot/)
- Native AppleHDA installed
- Layout-id: 3 for HDEF - HDMI audio

###Usage:

```
#Params fully optional
Layout-id: hdaInjector.sh -l 3 (stripdown data, 3 for HDMI)
Codec-id: hdaInjector.sh -c 892
```