compile wifi driver for orange pi pc plus (Firmware Android 10Q)

firmware
https://xdaforums.com/t/android-box-r69-latest-version.4248545/


adb root

adb remount

adb push 8189fs.ko /system/vendor/modules/8189fs.ko

adb reboot
