# Links Boot
Simple and fast bootloader

## How to compile
- First run compile script, by running ```./compile```. Compile script will create boot_fin.img and LINKSCND.BTT images.
boot_fin.img is meant to be writen to storage device using _dd_ command:
```dd if=boot_fin.img of="storage_device" bs=512 count=1```
- After that storage device will contain one FAT12/16 partition that needs to be mounted, and LINKSCND.BTT transfered to it.


Bootloader stages:
  * LinksBoot first stage (boot_fin.img) - Contains basic segment setup code and FAT fs and disk driver for second stage bootloader loading.
  * LinksBoot second stage (LINKSCND.BTT) - Contains full FAT and disk driver, GDT, IDT and A20 setup code, and code to load kernel
