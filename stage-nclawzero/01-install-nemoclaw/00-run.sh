#!/bin/bash -e
# Runs OUTSIDE chroot — installs files from stage files/ into target rootfs.

install -Dm0644 files/nvidia-desktop.jpg \
    "${ROOTFS_DIR}/usr/share/backgrounds/nclawzero/nvidia-desktop.jpg"

# System-wide XFCE4 default backdrop. This path + property names match
# xfconf's xfce4-desktop channel schema. Applied to every user on first
# login since /etc/xdg is merged with ~/.config for XFCE session init.
install -d "${ROOTFS_DIR}/etc/xdg/xfce4/xfconf/xfce-perchannel-xml"
cat > "${ROOTFS_DIR}/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorrdp0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nclawzero/nvidia-desktop.jpg"/>
        </property>
      </property>
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nclawzero/nvidia-desktop.jpg"/>
        </property>
      </property>
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nclawzero/nvidia-desktop.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
