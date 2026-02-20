FROM alpine:latest

# Copy the optimizer script
COPY manager.sh /usr/local/bin/manager.sh
RUN chmod +x /usr/local/bin/manager.sh

RUN apk add --no-cache bash util-linux

# 2. PERMANENT CONFIG: Create /etc/fstab
# This tells the VM to always mount the root disk (/dev/vda) 
# with high-performance Ext4 settings.
RUN echo "/dev/vda / ext4 noatime,commit=60,errors=remount-ro 0 1" > /etc/fstab



WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/manager.sh"]