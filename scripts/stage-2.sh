#!/bin/bash
echo -e "\nПродолжаем работу..."
echo "Удалим раздел, требующий уменьшения и создадим его с новым объемом в 8 Гб..."
sudo lvremove -f /dev/VolGroup00/LogVol00
sudo lvcreate -y -n LogVol00 -L 8G VolGroup00
sudo mkfs.xfs -f -q /dev/VolGroup00/LogVol00
echo -e "\nМонтируем его и переносим систему на вновь созданный раздел..."
sudo mount /dev/VolGroup00/LogVol00 /mnt
sudo xfsdump -v silent -J - /dev/vg_tmp_root/lv_tmp_root | sudo xfsrestore -v silent -J - /mnt
for i in /proc/ /sys/ /dev/ /run/ /boot/; do sudo mount --bind $i /mnt/$i; done
echo -e "\nЗаписываем новый загрузчик и правим grub.cfg"
sudo chroot /mnt sh -c "grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1"
sudo chroot /mnt mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.old2
sudo chroot /mnt sh -c "dracut /boot/initramfs-$(uname -r).img $(uname -r) > /dev/null 2>&1"
sudo sed -i 's+vg_tmp_root/lv_tmp_root+VolGroup00/LogVol00+g' /boot/grub2/grub.cfg
echo -e "\n!!!====================================================================!!!"
echo "!!!                                                                    !!!"
echo "!!!                      Система перезагружается                       !!!"
echo "!!!                                                                    !!!"
echo "!!!       После перезагрузки войдите в систему и запустите скрипт,     !!!"
echo "!!!                   завершающий перенос системы                     !!!"
echo "!!!                          vagrant ssh                               !!!"
echo "!!!                      ./scripts/stage-3.sh                          !!!"
echo "!!!                                                                    !!!"
echo "!!!====================================================================!!!"
sudo shutdown -r now
