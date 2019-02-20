# alpha-bleeding-d
A small tool to bleed the border colors of an image (PNG only) with transparency through the pixels that are fully transparent.

Based on https://github.com/urraka/alpha-bleeding

`alpha_bleeding.exe [options] source [destination]`

Options:
```
--replace, -r    Overwrite original file
--noalpha, -n    Store an extra image with removed alpha
```

Examples of use:
```
alpha_bleeding.exe -replace -noalpha file.png
alpha_bleeding.exe -replace directory
alpha_bleeding.exe directory
alpha_bleeding.exe directory_source directory_destination
alpha_bleeding.exe file.png
alpha_bleeding.exe file.png result.png
```
