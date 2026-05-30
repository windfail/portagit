.PHONY: nothing install

nothing:


install:
	install -d $(DESTDIR)/bin
	install -m 0755 -t $(DESTDIR)/bin custom-update auto_emerge portagit-snapshot
	install -d $(DESTDIR)/etc/grub.d
	install -m 0755 -t $(DESTDIR)/etc/grub.d 42_snapshots
