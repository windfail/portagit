.PHONY: nothing install

nothing:


install:
	install -d $(DESTDIR)/bin
	install -m 0755 -t $(DESTDIR)/bin custom-update auto_emerge btrfs-snapshot.sh
