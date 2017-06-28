#############################################################################
# Makefile for building: pc-updatemanager
#############################################################################

PREFIX?= /usr/local

AR            = ar cqs
RANLIB        = 
TAR           = tar -cf
COMPRESS      = gzip -9f
COMPRESS_MAN	= gzip -c
COPY          = cp -f
SED           = sed
COPY_FILE     = $(COPY)
COPY_DIR      = $(COPY) -R
STRIP         = 
INSTALL_FILE  = $(COPY_FILE)
INSTALL_DIR   = $(COPY_DIR)
INSTALL_PROGRAM = $(COPY_FILE)
DEL_FILE      = rm -f
SYMLINK       = ln -f -s
DEL_DIR       = rmdir
MOVE          = mv -f
CHK_DIR_EXISTS= test -d
MKDIR         = mkdir -p

first: all

all:

install_scripts: first FORCE
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/bin/ || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/bin/
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/ || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/etc/init.d/ || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/etc/init.d/
	-$(INSTALL_FILE) pc-updatemanager $(INSTALL_ROOT)$(PREFIX)/bin/
	-$(INSTALL_FILE) pc-autoupdate $(INSTALL_ROOT)$(PREFIX)/bin/
	-$(INSTALL_FILE) rc-update $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/
	-$(INSTALL_FILE) rc-doupdate $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/
	-$(INSTALL_FILE) fbsd-dist.pub $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/
	-$(INSTALL_FILE) init.d/trueos-ipfs $(INSTALL_ROOT)$(PREFIX)/etc/init.d/
	-$(COMPRESS_MAN) pc-updatemanager.8 > $(INSTALL_ROOT)$(PREFIX)/man/man8/pc-updatemanager.8.gz


uninstall_scripts:  FORCE
	-$(DEL_FILE) -r $(INSTALL_ROOT)$(PREFIX)/bin/pc-updatemanager
	-$(DEL_FILE) -r $(INSTALL_ROOT)$(PREFIX)/bin/pc-autoupdate
	-$(DEL_FILE) -r $(INSTALL_ROOT)$(PREFIX)/etc/init.d/trueos-ipfs
	-$(DEL_DIR) $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager


install_dochmod: first FORCE
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/bin/ || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/bin/ 
	chmod 755 $(PREFIX)/bin/pc-updatemanager
	chmod 755 $(PREFIX)/bin/pc-autoupdate

install_conf: first FORCE
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/ || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/
	-$(INSTALL_DIR) conf $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/

install_pcupdated: first FORCE
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/ || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/pre || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/pre
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/post || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/post
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/etc/pkg/repos || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/etc/pkg/repos
	@$(CHK_DIR_EXISTS) $(INSTALL_ROOT)$(PREFIX)/etc/pkg/fingerprints/trueos/trusted || $(MKDIR) $(INSTALL_ROOT)$(PREFIX)/etc/pkg/fingerprints/trueos/trusted
	-$(INSTALL_FILE) certs/pkg.cdn.trueos.org.20160701 $(INSTALL_ROOT)$(PREFIX)/etc/pkg/fingerprints/trueos/trusted/
	-$(INSTALL_FILE) repos/trueos.conf.dist $(INSTALL_ROOT)$(PREFIX)/etc/pkg/repos/
	-$(INSTALL_FILE) pcupdate.d/pre/README $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/pre/README
	-$(INSTALL_FILE) pcupdate.d/post/README $(INSTALL_ROOT)$(PREFIX)/etc/pcupdate.d/post/README

uninstall_conf:  FORCE
	-$(DEL_FILE) -r $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager/conf
	-$(DEL_DIR) $(INSTALL_ROOT)$(PREFIX)/share/trueos/pc-updatemanager


install:  install_scripts install_dochmod install_conf install_pcupdated  FORCE

uninstall: uninstall_scripts uninstall_conf  FORCE

FORCE:
