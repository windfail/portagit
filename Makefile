.PHONY: nothing

nothing:


install:
	install -d $(DESTDIR)/bin
	install -t $(DESTDIR)/bin custom-update
