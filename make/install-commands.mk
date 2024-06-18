install-pkgconfig:
	install -d $(PREFIX)/lib/pkgconfig
	install -m 644 $(PKG_CONFIG) $(PREFIX)/lib/pkgconfig

install-lib:
	install -d $(PREFIX)/include
	install -d $(PREFIX)/lib
	install -m 644 $(MODULES) $(PREFIX)/include
	install $(OBJ_OUT) $(PREFIX)/lib

install-exec:
	install -d $(PREFIX)/include
	install -d $(PREFIX)/bin
	install $(OBJ_OUT) $(PREFIX)/bin

install-includes:
	install -d $(PREFIX)/include
	if [[ "$(INSTALL_INCLUDES)" ]]; then \
	  for f in "$(INSTALL_INCLUDES)"; do \
	    install -m 644 $$f $(PREFIX)/include; \
	  done; \
	fi

INSTALL_COMMANDS += install-includes
