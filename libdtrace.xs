#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <dtrace.h>

/* C++ Functions */

MODULE = Devel::libdtrace              PACKAGE = Devel::libdtrace

# XS code

PROTOTYPES: ENABLED

SV *
new( const char *class )
  CODE:
    /* Create a hash */
    HV* hash = newHV();

    /* Create a reference to the hash */
    SV* const self = newRV_noinc( (SV *)hash );

    /* bless into the proper package */
    RETVAL = sv_bless( self, gv_stashpv( class, 0 ) );
  OUTPUT: RETVAL

const char *
version(...)
  CODE:
    RETVAL = "0.0.2";
  OUTPUT: RETVAL

