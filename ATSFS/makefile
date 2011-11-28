
ATSCC=atscc
ATSOPT=atsopt

XRFLAGS=`pkg-config cairo --cflags --libs`
GTKFLAGS=`pkg-config gtk+-2.0 --cflags --libs`

######

.PHONY: all
all: 
	echo "eeee"

######

.PHONY: typecheck

typecheck: atsfs.sats
	$(ATSCC) -tc $<
	

######

persis: persis.dats
	$(ATSCC) -o $@  persis.dats

testRational: rational.dats rational.sats testRational.dats
	$(ATSCC) -o $@ rational.sats rational.dats testRational.dats

fractal_koch: fractal_koch.dats
	$(ATSCC) -o $@ fractal_koch.dats $(GTKFLAGS)

######
html::
	$(ATSOPT) --posmark_html -d persis.dats > persis.html

clean::
	rm -f *~ *_?ats.c *_?ats.o

cleanall: clean
	rm -f persis

