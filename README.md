# Red Eclipse AppImage builder

This project contains files and scripts that allow the easy, reproducible and
incremental generation of AppImages for the
[Red Eclipse](http://redeclipse.net) project.

Software required to use this project is Vagrant, the Vagrant LXC plugin, LXC
and FUSE. You can most likely install those using your distribution's package
manager.

On Debian/Ubuntu based systems, run:

    user@host:~/redeclipse-appimage$ sudo apt install vagrant vagrant-lxc \
        fuse lxc

Then create the LXC container:

    user@host:~/redeclipse-appimage$ vagrant up

If it prompts for a sudo password, please enter your password.

After the creation is done, log into the container using:

    user@host:~/redeclipse-appimage$ vagrant ssh

Inside the container, navigate to `/vagrant` and run the build script:

    vagrant@vagrant-base-wheezy-amd64:~$ cd /vagrant
    vagrant@vagrant-base-wheezy-amd64:/vagrant$ sudo ./build-appimage.sh

If you have already run the script before in this container, it will prompt
you to choose if you want to clean up the workspace and thus perform a clean
rebuild of the AppImage, or if you want to build incrementally (which greatly
reduces the required time amount and is generally safe to use).

The final AppImage will be put in the directory you started the LXC
container from:

    vagrant@vagrant-base-wheezy-amd64:~$ exit
    user@host:~/redeclipse-appimage$ ls -l out/
    redeclipse-1.5.6-x86_64.AppImage

You can then distribute the AppImage.

Beware that you should NOT put the AppImage in any further archives. Read the
AppImage documentation for more information.
