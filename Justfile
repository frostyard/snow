set dotenv-load := true

image_name := env("BUILD_IMAGE_NAME", "snow")
base_image_name := env("BUILD_BASE_IMAGE_NAME", "debian-bootc-core")
image_repo := env("BUILD_IMAGE_REPO", "ghcr.io/frostyard")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "btrfs")
selinux := path_exists('/sys/fs/selinux')
ovmf_code := env("OVMF_CODE", "/opt/incus/share/qemu/OVMF_CODE.4MB.fd")
ovmf_vars_orig := env("OVMF_VARS_ORIG", "/opt/incus/share/qemu/OVMF_VARS.4MB.ms.fd")

default:
    just --list --unsorted

build-container $image_name=image_name:
    sudo podman pull "{{ image_repo }}/{{ base_image_name }}:latest" || true
    sudo podman build --no-cache -t "{{ image_name }}:{{ image_tag }}" .

run-container $image_name=image_name:
    sudo podman run --rm -it "{{ image_name }}:{{ image_tag }}" bash

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        -v /var/lib/containers:/var/lib/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        {{ if selinux == 'true' { '-v /sys/fs/selinux:/sys/fs/selinux' } else { '' } }} \
        {{ if selinux == 'true' { '--security-opt label=type:unconfined_t' } else { '' } }} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        "{{ image_name }}:{{ image_tag }}" bootc {{ ARGS }}


getfiles:
    #!/usr/bin/env bash
    IMG="{{ image_name }}:{{ image_tag }}"
    mnt=$(sudo podman image mount $IMG)
    echo "Mounted image $IMG at $mnt"
    sudo cp -r $mnt/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed .
    sudo cp -r $mnt/usr/lib/shim/shimx64.efi.signed .
    sudo cp -r $mnt/usr/lib/shim/mmx64.efi.signed .
    sudo cp -r $mnt/usr/lib/shim/fbx64.efi.signed .
    sudo podman image unmount $IMG

# accelerate bootc image building with /tmp
setup-bootc-accelerator:
    #!/usr/bin/env bash
    echo "BUILD_BASE_DIR=/tmp" > .env

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just bootc install to-disk \
            --composefs-backend \
            --via-loopback /data/${image_filename} \
            --filesystem "{{ filesystem }}" \
            --block-setup direct \
            --target-imgref {{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --wipe \
            --bootloader systemd \
            --karg "splash" \

    # mount the image and apply secure boot fixes
    # sudo losetup -l
    loopdev=$(sudo losetup --show -fP "{{ base_dir }}/${image_filename}")
    MOUNTPOINT=/mnt/install-image-snow

    sudo mkdir -p ${MOUNTPOINT}
    sudo mount "${loopdev}p2" ${MOUNTPOINT}
    echo "Install image mounted at ${MOUNTPOINT}"

    echo "Copying signed bootloader files to EFI partition"
    # copy systemd-bootx64.efi.signed to the mounted efi partition, renaming it to GRUBX64.efi
    # so it will chain load from shim
    sudo cp "systemd-bootx64.efi.signed" "$MOUNTPOINT/EFI/BOOT/GRUBX64.efi"

    # copy shimx64.efi.signed to the mounted efi partition, renaming it to BOOTX64.EFI
    # so it will be the default boot entry
    sudo cp "shimx64.efi.signed" "$MOUNTPOINT/EFI/BOOT/BOOTX64.EFI"

    # # finally uncomment the line in loader.conf that sets the timeout
    # # so that the boot menu appears, allowing the user to edit the kargs
    # # if needed to unlock the disk
    sudo sed -i 's/^#timeout/timeout/' "$MOUNTPOINT/loader/loader.conf"
    sudo umount ${MOUNTPOINT}
    sudo rm -rf ${MOUNTPOINT}
    sudo losetup -d ${loopdev}


generate-install-image $base_dir=base_dir $filesystem=filesystem: getfiles
    #!/usr/bin/env bash
    image_filename={{ image_name }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 12G "{{ base_dir }}/${image_filename}"
    fi
    just bootc install to-disk \
            --composefs-backend \
            --via-loopback /data/${image_filename} \
            --block-setup direct \
            --filesystem "{{ filesystem }}" \
            --target-imgref {{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --wipe \
            --bootloader systemd \
            --karg "splash" \
            --karg "snow-linux.live=1"

    # mount the image and apply secure boot fixes
    # sudo losetup -l
    loopdev=$(sudo losetup --show -fP "{{ base_dir }}/${image_filename}")
    MOUNTPOINT=/mnt/install-image-snow

    sudo mkdir -p ${MOUNTPOINT}
    sudo mount "${loopdev}p2" ${MOUNTPOINT}
    echo "Install image mounted at ${MOUNTPOINT}"

    echo "Copying signed bootloader files to EFI partition"
    # copy systemd-bootx64.efi.signed to the mounted efi partition, renaming it to GRUBX64.efi
    # so it will chain load from shim
    sudo cp "systemd-bootx64.efi.signed" "$MOUNTPOINT/EFI/BOOT/GRUBX64.efi"

    # copy shimx64.efi.signed to the mounted efi partition, renaming it to BOOTX64.EFI
    # so it will be the default boot entry
    sudo cp "shimx64.efi.signed" "$MOUNTPOINT/EFI/BOOT/BOOTX64.EFI"

    # # finally uncomment the line in loader.conf that sets the timeout
    # # so that the boot menu appears, allowing the user to edit the kargs
    # # if needed to unlock the disk
    sudo sed -i 's/^#timeout/timeout/' "$MOUNTPOINT/loader/loader.conf"
    sudo umount ${MOUNTPOINT}
    sudo rm -rf ${MOUNTPOINT}
    sudo losetup -d ${loopdev}

bootable-image-from-ghcr $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just bootc install to-disk \
            --composefs-backend \
            --via-loopback /data/${image_filename} \
            --block-setup direct \
            --filesystem "{{ filesystem }}" \
            --source-imgref docker://{{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --target-imgref {{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --wipe \
            --bootloader systemd \
            --karg "splash"

launch-incus:
    #!/usr/bin/env bash
    ## commented out because nbc creates the image below
    # image_file={{ base_dir }}/{{ image_name }}.img

    # if [ ! -f "$image_file" ]; then
    #     echo "No image file found, generate-bootable-image first"
    #     exit 1
    # fi

    abs_image_file=$(realpath "$image_file")

    instance_name="{{ image_name }}"
    echo "Creating instance $instance_name from image file $abs_image_file"
    incus init "$instance_name" --empty --vm
    incus config device override "$instance_name" root size=50GiB
    incus config set "$instance_name" limits.cpu=4 limits.memory=8GiB
    incus config set "$instance_name" security.secureboot=true
    incus config device add "$instance_name" vtpm tpm
    incus config device add "$instance_name" install disk source="$abs_image_file" boot.priority=90
    incus start "$instance_name"
    echo "$instance_name is Starting..."
    incus console --type=vga "$instance_name"

remove-install-device:
    #!/usr/bin/env bash
    instance_name="{{ image_name }}"
    echo "Removing install device from instance $instance_name"
    incus config device remove "$instance_name" install || true

console:
    #!/usr/bin/env bash
    instance_name="{{ image_name }}"
    # start the instance if it is not running
    state=$(incus info "$instance_name" | grep 'Status:' | awk '{print $2}')
    if [ "$state" != "Running" ]; then
        echo "Instance $instance_name is not running. Starting it..."
        incus start "$instance_name"
    fi
    echo "Connecting to console of instance $instance_name"
    incus console --type=vga "$instance_name"

rm-incus:
    #!/usr/bin/env bash
    instance_name="{{ image_name }}"
    echo "Stopping and removing instance $instance_name"
    incus rm --force "$instance_name" 2>/dev/null || true
    image_file={{ base_dir }}/{{ image_name }}.img
    echo "Removing image file $image_file"
    rm -f "$image_file" || true

qemu:
    #!/usr/bin/env bash
    image_file={{ base_dir }}/{{ image_name }}.img
    OVMF_VARS="$(basename "{{ ovmf_vars_orig }}")"
    if [ ! -e "${OVMF_VARS}" ]; then
        cp "{{ ovmf_vars_orig }}" "${OVMF_VARS}"
    fi
    qemu-system-x86_64 \
        -machine pc-q35-10.0 \
        -m 8G \
        -smp 4 \
        -cpu host \
        -enable-kvm \
        -vga virtio \
        -drive if=pflash,format=raw,unit=0,file="{{ ovmf_code }}",readonly=on \
        -drive if=pflash,format=raw,unit=1,file="${OVMF_VARS}" \
        -drive file=$image_file,format=raw,if=virtio

nbc-image:
    #!/usr/bin/env bash
    sudo rm -f /tmp/snow.img
    sudo nbc install --via-loopback /tmp/snow.img --image localhost/snow:latest --skip-pull