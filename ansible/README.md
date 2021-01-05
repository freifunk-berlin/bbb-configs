# network/ankibinn

### How to get started

```
pip3 install -r requirements.txt
```

### How to spin up a config run (generate only, output path is /tmp/configs/..:

```
ansible-playbook play.yml
```

### How to spin up a config run and generate images

```
ansible-playbook play.yml --tags image
```

### How to spin up a config run, generate image and flash (to be implemented)

```
ansible-playbook play.yml --tags flash
```

### Whats required to bringup a location?

```
/group_vars : Create location folder
/host_vars : Create host folder for every openwrt device
Done!

```
