.PHONY: status logs restart backup update harden persona

status logs restart backup update harden persona:
	$(MAKE) -C server $@
