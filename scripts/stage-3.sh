#!/bin/bash
echo -e "Продолжаем работу...\n"
sudo lvremove -f /dev/vg_tmp_root/lv_tmp_root > /dev/null 2>&1
sudo vgremove vg_tmp_root > /dev/null 2>&1
sudo pvremove /dev/sdb > /dev/null 2>&1
echo -e "Вывод команды lsblk после уменьшения раздела:\n"
lsblk
sleep 5
echo "Создаем раздел home..."
sudo lvcreate -L 1G -n home VolGroup00
echo -e "\nСоздаем зеркальный раздел var..."
sudo lvcreate -L 1G -m1 --alloc anywhere -n var VolGroup00
echo -e "\nФорматируем созданные разделы..."
sudo mkfs.xfs -q /dev/VolGroup00/home
sudo mkfs.xfs -q /dev/VolGroup00/var
echo -e "\nПереносим существующие данные на новые разделы (--надо в однопользовательском режиме--)"
sudo mkdir /mnt/home /mnt/var
sudo mount /dev/VolGroup00/home /mnt/home
sudo mount /dev/VolGroup00/var /mnt/var
sudo rsync -axu /home/ /mnt/home/
sudo rsync -axu /var/ /mnt/var/
echo -e "\nДобавим новые точки монтирования в fstab и смонтируем новые разделы вместо старых"
echo "UUID=`sudo blkid -s UUID -o value /dev/VolGroup00/home` /home  xfs  defaults  0 0" | sudo tee -a /etc/fstab
echo "UUID=`sudo blkid -s UUID -o value /dev/VolGroup00/var` /var  xfs  defaults  0 0" | sudo tee -a /etc/fstab
cd /
sudo umount -f /mnt/home
sudo umount -f /mnt/var
sudo mount -U `sudo blkid -s UUID -o value /dev/VolGroup00/home` /home
sudo mount -U `sudo blkid -s UUID -o value /dev/VolGroup00/var` /var
echo -e "\nВывод команды lsblk после создания всех разделов:\n"
lsblk
sleep 5
echo -e "\nСгенерируем файлы в home"
for i in {1..9}; do dd if=/dev/zero of=/home/vagrant/file_$i bs=1M count=10 2> /dev/null; done
echo -e "\nФайлы в директории до удаления:"
ls -l /home/vagrant/
sleep 2
echo -e "\nСоздаем snapshot"
sudo lvcreate --size 1G --snapshot --name home_snapshot /dev/VolGroup00/home
echo -e "\nУдалим часть файлов..."
for i in {1..5}; do rm -f /home/vagrant/file_$i; done
echo -e "\nФайлы в директории после удаления:"
ls -l /home/vagrant/
sleep 2
echo -e "\nОтмонтируем раздел home (--надо в однопользовательском режиме--)"
sudo umount -f /home
echo -e "\nВосстановим snapshot"
sudo lvconvert --merge /dev/VolGroup00/home_snapshot
sudo mount /home
echo -e "\nФайлы в директории после восстановления"
ls -l /home/vagrant/
sleep 5

echo -e "\n\nДалее задание со звёздочкой..."
echo "Файловая система btrfs"
sleep 2
echo -e "\nУстановим необходимые программы..."
sudo yum install -y -q btrfs-progs
echo -e "\nСоздаем файловую систему btrfs на дисках по 1Gb, создаем сабволюм и смонтируем его в /opt_btrfs"
sudo mkfs.btrfs -q /dev/sdd /dev/sde # создаем файловую систему btrfs на двух дисках
sudo mkdir /btrfs /opt_btrfs # создаем директории для монтирования файловой системы и монтирования сабволюма
sudo mount /dev/sdd /btrfs # монтируем файловую систему в каталог /btrfs
sudo btrfs subvolume create /btrfs/opt # создаем сабволюм
sudo mount -t btrfs -o subvol=opt,defaults /dev/disk/by-uuid/`sudo blkid -s UUID -o value /dev/sde` /opt_btrfs # монтируем сабволюм в каталог /opt_btrfs
sudo umount /btrfs
echo -e "\nВывод команды df -h после монтирования сабволюма в каталог /opt_btrfs:"
df -h
sleep 2
echo -e "\nСгенерируем файлы в /opt_btrfs"
for i in {1..9}; do sudo dd if=/dev/zero of=/opt_btrfs/file_$i bs=1M count=10 2> /dev/null; done
echo -e "\nФайлы в директории до удаления:"
ls -l /opt_btrfs/
sleep 2
echo -e "\nСоздаем snapshot"
sudo btrfs subvolume snapshot /opt_btrfs /opt_btrfs/snapshot
echo -e "\nУдалим часть файлов"
for i in {1..5}; do sudo rm -f /opt_btrfs/file_$i; done
echo -e "\nФайлы в директории после удаления"
ls -l /opt_btrfs/
sleep 2
echo -e "\nВосстановим файлы из snapshot'а (простым перемещением) и удалим snapshot"
sudo mv /opt_btrfs/snapshot/* /opt_btrfs
sudo btrfs subvolume delete /opt_btrfs/snapshot/
echo -e "\nФайлы в директории после восстановления"
ls -l /opt_btrfs/
sleep 5


echo -e "\nФайловая система zfs"
sleep 2
sudo yum install -y -q http://download.zfsonlinux.org/epel/zfs-release.el7_5.noarch.rpm
echo "Запретим установку модулей DKMS и разрешим установку модулей kABI (займёт некоторое время)"
sudo yum-config-manager --disable zfs > /dev/null 2>&1
sudo yum-config-manager --enable zfs-kmod > /dev/null 2>&1
echo -e "\nУстановим необходимые программы...(займёт некоторое время)"
sudo yum install zfs -y -q
sudo /sbin/modprobe zfs
echo -e "\nСоздадим stripe pool из дисков sdb и sdc"
sudo zpool create mypool /dev/sdb /dev/sdc
echo "Создадим файловую систему и примонтируем её в домашнем каталоге"
sudo zfs create mypool/mydirectory && sudo zfs set mountpoint=/home/vagrant/mydirectory mypool/mydirectory
echo -e "\nВывод команды lsblk"
lsblk
sleep 5
echo -e "\n!!!====================================================================!!!"
echo "!!!  Дальше не вижу смысла работать здесь с ZFS при наличии отдельной  !!!"
echo "!!!                            лекции по ней.                          !!!"
echo "!!!                                                                    !!!"
echo "!!!            Если кратко, добавим кэширующий диск командой           !!!"
echo "!!!                    zpool add mypool cache device(s)                !!!"
echo "!!!                  Создадим файловую систему командой                !!!"
echo "!!!                    zfs create mypool/directory                     !!!"
echo "!!!                     Создаем снапшот командой                       !!!"
echo "!!!                zfs snapshot mypool/directory@snapshotName          !!!"
echo "!!!                      Восстанавливаем командой                      !!!"
echo "!!!                            zfs rollback                            !!!"
echo "!!!                                                                    !!!"
echo "!!!                         Спасибо за проверку!                       !!!"
echo "!!!====================================================================!!!"
