# -*- mode: ruby -*-
# vim: set ft=ruby :
home = ENV['HOME']
ENV["LC_ALL"] = "en_US.UTF-8"

MACHINES = {
  :lvm => {
        :box_name => "centos/7",
        :box_version => "1804.02",
        :ip_addr => '192.168.11.101',
    :disks => {
        :sata1 => {
            :dfile => home + '/VirtualBox VMs/sata1.vdi',
            :size => 10240,
            :port => 1
        },
        :sata2 => {
            :dfile => home + '/VirtualBox VMs/sata2.vdi',
            :size => 2048, # Megabytes
            :port => 2
        },
        :sata3 => {
            :dfile => home + '/VirtualBox VMs/sata3.vdi',
            :size => 1024, # Megabytes
            :port => 3
        },
        :sata4 => {
            :dfile => home + '/VirtualBox VMs/sata4.vdi',
            :size => 1024,
            :port => 4
        }
    }
  },
}

Vagrant.configure("2") do |config|

    config.vm.box_version = "1804.02"
    config.vbguest.no_install = true
    MACHINES.each do |boxname, boxconfig|

        config.vm.define boxname do |box|

            box.vm.box = boxconfig[:box_name]
            box.vm.host_name = boxname.to_s

            #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset

            box.vm.network "private_network", ip: boxconfig[:ip_addr]

            box.vm.provider :virtualbox do |vb|
                    vb.customize ["modifyvm", :id, "--memory", "256"]
                    needsController = false
            boxconfig[:disks].each do |dname, dconf|
                unless File.exist?(dconf[:dfile])
                  vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size]]
                                  needsController =  true
                            end

            end
                    if needsController == true
                       vb.customize ["storagectl", :id, "--name", "SATA", "--add", "sata" ]
                       boxconfig[:disks].each do |dname, dconf|
                           vb.customize ['storageattach', :id,  '--storagectl', 'SATA', '--port', dconf[:port], '--device', 0, '--type', 'hdd', '--medium', dconf[:dfile]]
                       end
                    end
            end
        box.vm.provision "file", source: "./scripts", destination: "/home/vagrant/scripts"
        box.vm.provision "shell", inline: <<-SHELL
            clear
            mkdir -p ~root/.ssh
            cp ~vagrant/.ssh/auth* ~root/.ssh
            echo "Вывод команды lsblk до уменьшения раздела:"
            lsblk
            echo "Устанавливаем необходимые программы"
            yum install -y -q mdadm smartmontools hdparm gdisk lvm2 xfsdump
            echo "*** Отключаем SELINUX ***"
            setenforce 0
            echo SELINUX=disabled > /etc/selinux/config
            echo "Создаем и монтируем временный раздел LVM для корня"
            pvcreate /dev/sdb
            vgcreate vg_tmp_root /dev/sdb
            lvcreate -n lv_tmp_root -l +100%FREE /dev/vg_tmp_root
            mkfs.xfs -q /dev/vg_tmp_root/lv_tmp_root
            mount /dev/vg_tmp_root/lv_tmp_root /mnt
            echo "Копируем содержимое корневого каталога во временный раздел"
            xfsdump -v silent -J - /dev/VolGroup00/LogVol00 | xfsrestore -v silent -J - /mnt
            echo "Монтируем оставшиеся каталоги, создаем новый initramfs и записываем новый загрузчик"
            for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
            chroot /mnt sh -c "grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1"
            chroot /mnt mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.old
            chroot /mnt dracut /boot/initramfs-$(uname -r).img $(uname -r)
            chroot /mnt sed -i 's+VolGroup00/LogVol00+vg_tmp_root/lv_tmp_root+g' /boot/grub2/grub.cfg
            echo "!!!====================================================================!!!"
            echo "!!!                                                                    !!!"
            echo "!!!                      Система перезагружается                       !!!"
            echo "!!!                                                                    !!!"
            echo "!!!       После перезагрузки войдите в систему и запустите скрипт,     !!!"
            echo "!!!                   продолжающий перенос системы                     !!!"
            echo "!!!                          vagrant ssh                               !!!"
            echo "!!!                      ./scripts/stage-2.sh                          !!!"
            echo "!!!                                                                    !!!"
            echo "!!!====================================================================!!!"

            shutdown -r now > /dev/null 2>&1
          SHELL

        end
    end
  end
