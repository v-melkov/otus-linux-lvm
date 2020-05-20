# stands-03-lvm

Стенд для домашнего занятия "Файловые системы и LVM"

Домашнее задание
Работа с LVM
на имеющемся образе
/dev/mapper/VolGroup00-LogVol00 38G 738M 37G 2% /

1. уменьшить том под / до 8G
2. выделить том под /home
3. выделить том под /var
4. /var - сделать в mirror
5. /home - сделать том для снэпшотов
6. прописать монтирование в fstab
7. сгенерить файлы в /home/
8. снять снэпшот
9. удалить часть файлов
10. восстановится со снэпшота

-------

Перенос системы на меньший диск выполнени путём переноса существующей системы на запасной диск, уменьшение размера тома / и переноса системы обратно.

Работа стенда предполагает две перезагрузки и два ручных запуска скриптов.

--------

## Команды, выполняемые в Vagrantfile:

Переносим файлы со скриптами на машину:

    box.vm.provision "file", source: "./scripts", destination: "/home/vagrant/scripts"

##### Посмотрим вывод команды lsblk до уменьшения раздела:
    lsblk
##### Установим необходимые программы:
    yum install -y -q mdadm smartmontools hdparm gdisk lvm2 xfsdump
##### Отключим SELINUX
    setenforce 0
    echo SELINUX=disabled > /etc/selinux/config
##### Создадим и смонтируем временный раздел LVM для корня на диске sdb:
    pvcreate /dev/sdb
    vgcreate vg_tmp_root /dev/sdb
    lvcreate -n lv_tmp_root -l +100%FREE /dev/vg_tmp_root
    mkfs.xfs -q /dev/vg_tmp_root/lv_tmp_root
    mount /dev/vg_tmp_root/lv_tmp_root /mnt
##### Скопируем содержимое корневого каталога во временный раздел:
    xfsdump -v silent -J - /dev/VolGroup00/LogVol00 | xfsrestore -v silent -J - /mnt
##### Смонтируем оставшиеся каталоги, создадим новый initramfs и запишем новый загрузчик:
    for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
    chroot /mnt sh -c "grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1"
    chroot /mnt mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.old
    chroot /mnt dracut /boot/initramfs-$(uname -r).img $(uname -r)
    chroot /mnt sed -i 's+VolGroup00/LogVol00+vg_tmp_root/lv_tmp_root+g' /boot/grub2/grub.cfg

-----

Далее система перезагружается первый раз, после перезагрузки необходимо войти в систему

    vagrant ssh
и запустить скрипт, продолжающий перенос системы

    ./scripts/stage-2.sh
------

## Команды, выполняемые в скрипте stage-2.sh:
##### Удалим раздел, требующий уменьшения и создадим его с новым объемом в 8 Гб
    sudo lvremove -f /dev/VolGroup00/LogVol00
    sudo lvcreate -y -n LogVol00 -L 8G VolGroup00
    sudo mkfs.xfs -f -q /dev/VolGroup00/LogVol00

##### Монтируем его и переносим систему на вновь созданный раздел
    sudo mount /dev/VolGroup00/LogVol00 /mnt
    sudo xfsdump -v silent -J - /dev/vg_tmp_root/lv_tmp_root | sudo xfsrestore -v silent -J - /mnt
    for i in /proc/ /sys/ /dev/ /run/ /boot/; do sudo mount --bind $i /mnt/$i; done
##### Записываем новый загрузчик и правим grub.cfg
    sudo chroot /mnt sh -c "grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1"
    sudo chroot /mnt mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.old2
    sudo chroot /mnt sh -c "dracut /boot/initramfs-$(uname -r).img $(uname -r) > /dev/null 2>&1"
    sudo sed -i 's+vg_tmp_root/lv_tmp_root+VolGroup00/LogVol00+g' /boot/grub2/grub.cfg
-----

Далее система перезагружается второй раз, после перезагрузки необходимо войти в систему

    vagrant ssh
и запустить скрипт, завершающий перенос системы

    ./scripts/stage-3.sh
-----
## Команды, выполняемые в скрипте stage-3.sh:

##### Удалим временный раздел
    sudo lvremove -f /dev/vg_tmp_root/lv_tmp_root > /dev/null 2>&1
    sudo vgremove vg_tmp_root > /dev/null 2>&1
    sudo pvremove /dev/sdb > /dev/null 2>&1
##### Посмотрим вывод команды lsblk после уменьшения раздела:
     lsblk
#### Система перенесена.
------
##### Создадим раздел home
    sudo lvcreate -L 1G -n home VolGroup00

##### Создадим зеркальный раздел var
    sudo lvcreate -L 1G -m1 --alloc anywhere -n var VolGroup00
##### Форматируем созданные разделы
    sudo mkfs.xfs -q /dev/VolGroup00/home
    sudo mkfs.xfs -q /dev/VolGroup00/var

##### Добавим новые точки монтирования в fstab

    echo "UUID=`sudo blkid -s UUID -o value /dev/VolGroup00/home` /home  xfs  defaults  0 0" | sudo tee -a /etc/fstab
    echo "UUID=`sudo blkid -s UUID -o value /dev/VolGroup00/var` /var  xfs  defaults  0 0" | sudo tee -a /etc/fstab

##### Переносим существующие данные на новые разделы
    sudo mkdir /mnt/home /mnt/var
    sudo mount /dev/VolGroup00/home /mnt/home
    sudo mount /dev/VolGroup00/var /mnt/var
Дальнейшие действия предполагают загрузку **в однопользовательском режиме**, переносе всех файлов с существующих каталогов /home и /var, удалении файлов с существующих каталогов /home и /var, их отмонтирование и монтирование выше созданных разделов в эти каталоги.

Для простоты проверки я сделаю это на работающей в многопользовательском режиме системе без удаления файлов и примонтирую разделы поверх существующих каталогов.

    sudo rsync -axu /home/ /mnt/home/
    sudo rsync -axu /var/ /mnt/var/

    cd /
    sudo umount -f /mnt/home && sudo mount -U `sudo blkid -s UUID -o value /dev/VolGroup00/home` /home
    sudo umount -f /mnt/var && sudo mount -U `sudo blkid -s UUID -o value /dev/VolGroup00/var` /var
##### Посмотрим вывод команды lsblk после создания всех разделов
    lsblk

##### Сгенерируем файлы в home
    for i in {1..9}; do dd if=/dev/zero of=/home/vagrant/file_$i bs=1M count=10 2> /dev/null; done
##### Посмотрим файлы в директории до удаления:
    ls -l /home/vagrant/
##### Создадим snapshot
    sudo lvcreate --size 1G --snapshot --name home_snapshot /dev/VolGroup00/home
##### Удалим часть файлов
    for i in {1..5}; do rm -f /home/vagrant/file_$i; done
##### Посмотрим файлы в директории после удаления:
    ls -l /home/vagrant/
##### Отмонтируем раздел home (опять же: необходимо в однопользовательском режиме)
    sudo umount -f /home
##### Восстановим snapshot
    sudo lvconvert --merge /dev/VolGroup00/home_snapshot
    sudo mount /home
##### Посмотрим файлы в директории после восстановления:
    ls -l /home/vagrant/


## Далее задание со звёздочкой
На нашей куче дисков попробовать поставить btrfs/zfs - с кешем, снэпшотами - разметить здесь каталог /opt

### Файловая система btrfs
##### Установим необходимые программы
    sudo yum install -y -q btrfs-progs
##### Создадим файловую систему btrfs на дисках по 1Gb, создадим сабволюм и смонтируем его в /opt_btrfs
    sudo mkfs.btrfs -q /dev/sdd /dev/sde # создаем файловую систему btrfs на двух дисках
    sudo mkdir /btrfs /opt_btrfs # создаем директории для монтирования файловой системы и монтирования сабволюма
    sudo mount /dev/sdd /btrfs # монтируем файловую систему в каталог /btrfs
    sudo btrfs subvolume create /btrfs/opt # создаем сабволюм
    sudo mount -t btrfs -o subvol=opt,defaults /dev/disk/by-uuid/`sudo blkid -s UUID -o value /dev/sde` /opt_btrfs # монтируем сабволюм в каталог /opt_btrfs
    sudo umount /btrfs
##### Посмотрим вывод команды df -h после монтирования сабволюма в каталог /opt_btrfs:
    df -h
##### Сгенерируем файлы в /opt_btrfs
    for i in {1..9}; do sudo dd if=/dev/zero of=/opt_btrfs/file_$i bs=1M count=10 2> /dev/null; done
##### Посмотрим файлы в директории до удаления:
    ls -l /opt_btrfs/
##### Создаем snapshot
    sudo btrfs subvolume snapshot /opt_btrfs /opt_btrfs/snapshot
##### Удалим часть файлов
    for i in {1..5}; do sudo rm -f /opt_btrfs/file_$i; done
##### Посмотрим файлы в директории после удаления
    ls -l /opt_btrfs/
##### Восстановим файлы из snapshot'а (простым перемещением) и удалим snapshot
    sudo mv /opt_btrfs/snapshot/* /opt_btrfs
    sudo btrfs subvolume delete /opt_btrfs/snapshot/
##### Посмотрим файлы в директории после восстановления
    ls -l /opt_btrfs/


### Файловая система zfs
##### Установим необходимые программы
      sudo yum install -y -q http://download.zfsonlinux.org/epel/zfs-release.el7_5.noarch.rpm
##### Запретим установку модулей DKMS и разрешим установку модулей kABI
    sudo yum-config-manager --disable zfs > /dev/null 2>&1
    sudo yum-config-manager --enable zfs-kmod > /dev/null 2>&1
    sudo yum install zfs -y -q
    sudo /sbin/modprobe zfs
##### Создадим stripe pool из дисков sdb и sdc
    sudo zpool create mypool /dev/sdb /dev/sdc
##### Создадим файловую систему и примонтируем её в домашнем каталоге
    sudo zfs create mypool/mydirectory
    sudo zfs set mountpoint=/home/vagrant/mydirectory mypool/mydirectory
    echo -e "\nВывод команды lsblk"
    lsblk    

Дальше не вижу смысла работать здесь с ZFS при наличии отдельной лекции по ней.

Если кратко, добавим кэширующий диск командой

    zpool add mypool cache device(s)

Создадим файловую систему командой

    zfs create mypool/directory
Создаем снапшот командой

    zfs snapshot mypool/directory@snapshotName
Восстанавливаем командой

    zfs rollback

## Спасибо за проверку!
