###Pre:

**hdaInjector.sh** originally maintain by [@theracermaster](https://github.com/theracermaster) for [Gigabyte-GA-Z77X-DSDT-Patch](https://github.com/theracermaster/Gigabyte-GA-Z77X-DSDT-Patch).

###Mods:

This mods specifically made for ALC892.

###Requirements:

- Native AppleHDA installed

###Usage:

```
#Params fully optional

Layout-id: ./hdaInjector.sh -l 3 (-l: 1/2/3)
Codec-id: ./hdaInjector.sh -c 892

#Bin Patch: (Use '#' as multiple patch pattern separator)
./hdaInjector.sh -b \x8b\x19\xd4\x11,\x92\x08\xec\x10#\x8a\x19\xd4\x11,\x00\x00\x00\x00
./hdaInjector.sh -b \x8b\x19\xd4\x11,\x92\x08\xec\x10 -b \x8a\x19\xd4\x11,\x00\x00\x00\x00
```