#### To run this code the assumption is that you already have:

##### a k8s master with one slave 

##### or an untainted master able to host 
- ltsp server 
- dhcp server
- nbd server
- tftp server

## Project's aim
Based on what is available [here](https://kubernetes.io/blog/2018/10/02/building-a-network-bootable-server-farm-for-kubernetes-with-ltsp/)
I was able to do the following:
- Build the base image based on Ubuntu 16.04 with LTSP server components : Tftp & Nbd servers
- After the build process I push the image against a docker registry in localhost based on official regstry:latest
- Added DHCP configuration & server on a secondary ip of my laptop ethernet's connection so that only clients connecting to that port will use my DHCP server (sudo ip addr add 192.166.0.1/24 broadcast 192.166.1.255 dev enp3s0 label enp3s0:1)

## Differences between my work and @kvaps
First of all let me thank him for the great input he provided to anyone that wants to experiment on this stuff.
- As his work is from 2018 more or less all the patches he had to apply in the build are no more necessary so I removed them.
- I'm using latest docker version available at the moment of writing
- I'm using daemon.json file to configure docker params rather than putting it into systemd's configuration
- I'm using aufs driver as I had some issues with overlay2 , but that might be because I'm using reaaaally old hardware,as this is a test env
- I've added DHCP configuration to host it on kubernetes directly
- I've slightly modified `lts.conf` configuration.

## Disclamer
- This is *not* production ready, if you bring all of this in a production environment is up to your responsability only.

## Next Steps
- Add docker registry deployment onto kuberentes.
- BugFixes
- Update to ubuntu 18.04
- Add CentOS
