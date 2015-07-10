
/*   #define PERL_NO_GET_CONTEXT */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <dtrace.h>

#ifndef B_TRUE
#define B_TRUE 1
#endif
#ifndef B_FALSE
#define B_FALSE 0
#endif

/* Context */
typedef struct {
  dtrace_hdl_t  *dtc_handle;
  /* dtc_templ ??? */
  /* dtc_args  ??? */
  SV                *dtc_callback;
  SV                *dtc_error;     /* This is a string / PV */
  AV                *dtc_ranges;
  dtrace_aggvarid_t  dtc_ranges_varid;
} CTX;

/* Pre-XS C Function Declarations */
SV              *error(const char *fmt, ...);
HV          *probedesc(const dtrace_probedesc_t *pd);
const char     *action(const dtrace_recdesc_t *rec, char *buf, int size);
boolean_t        valid(const dtrace_recdesc_t *rec);
SV             *record(SV *self, const dtrace_recdesc_t *rec, caddr_t addr);
int         bufhandler(const dtrace_bufdata_t *bufdata, void *object);
int         consume_callback_caller(const dtrace_probedata_t *data,
                                    const dtrace_recdesc_t   *rec,
                                    void                     *object);
AV *     ranges_cached(dtrace_aggvarid_t varid, void *object);
AV *      ranges_cache(dtrace_aggvarid_t varid, AV *ranges, void *object);
AV *   ranges_quantize(dtrace_aggvarid_t varid, void *object);
AV *  ranges_lquantize(dtrace_aggvarid_t varid, uint64_t, void *object);
AV * ranges_llquantize(dtrace_aggvarid_t varid, uint64_t, int, void *object);
int  aggwalk_callback_caller(const dtrace_aggdata_t *agg, void *object);

/* C Functions */

SV *
error(const char *fmt, ...)
{
  char buf[1024], buf2[1024];
  char *err = buf;
  va_list ap;

  va_start(ap, fmt);
  (void) vsnprintf(buf, sizeof (buf), fmt, ap);

  if (buf[strlen(buf) - 1] != '\n') {
    /*
     * If our error doesn't end in a newline, we'll append the strerror()
     * of errno.
     */
    (void) snprintf(err = buf2, sizeof (buf2), "%s: %s",
                    buf, strerror(errno));
  } else {
    buf[strlen(buf) - 1] = '\0';
  }

  return(sv_2mortal(newSVpv(err,0)));
}

HV *
probedesc(const dtrace_probedesc_t *pd)
{
  HV *probe;

  probe = newHV();

  hv_store(probe, "provider", strlen("provider"), newSVpv(pd->dtpd_provider, 0), 0);
  hv_store(probe, "module",   strlen("module"),   newSVpv(pd->dtpd_mod, 0), 0);
  hv_store(probe, "function", strlen("function"), newSVpv(pd->dtpd_func, 0), 0);
  hv_store(probe, "name",     strlen("name"),     newSVpv(pd->dtpd_name, 0), 0);

  return(probe);
}

const char *
action(const dtrace_recdesc_t *rec, char *buf, int size)
{
  static struct {
    dtrace_actkind_t action;
    const char *name;
  } act[] = {
    { DTRACEACT_NONE,       "<none>" },
    { DTRACEACT_DIFEXPR,    "<DIF expression>" },
    { DTRACEACT_EXIT,       "exit()" },
    { DTRACEACT_PRINTF,     "printf()" },
    { DTRACEACT_PRINTA,     "printa()" },
    { DTRACEACT_LIBACT,     "<library action>" },
    { DTRACEACT_USTACK,     "ustack()" },
    { DTRACEACT_JSTACK,     "jstack()" },
    { DTRACEACT_USYM,       "usym()" },
    { DTRACEACT_UMOD,       "umod()" },
    { DTRACEACT_UADDR,      "uaddr()" },
    { DTRACEACT_STOP,       "stop()" },
    { DTRACEACT_RAISE,      "raise()" },
    { DTRACEACT_SYSTEM,     "system()" },
    { DTRACEACT_FREOPEN,    "freopen()" },
    { DTRACEACT_STACK,      "stack()" },
    { DTRACEACT_SYM,        "sym()" },
    { DTRACEACT_MOD,        "mod()" },
    { DTRACEAGG_COUNT,      "count()" },
    { DTRACEAGG_MIN,        "min()" },
    { DTRACEAGG_MAX,        "max()" },
    { DTRACEAGG_AVG,        "avg()" },
    { DTRACEAGG_SUM,        "sum()" },
    { DTRACEAGG_STDDEV,     "stddev()" },
    { DTRACEAGG_QUANTIZE,   "quantize()" },
    { DTRACEAGG_LQUANTIZE,	"lquantize()" },
    { DTRACEAGG_LLQUANTIZE,	"llquantize()" },
    { DTRACEACT_NONE,	NULL },
  };

  dtrace_actkind_t action = rec->dtrd_action;
  int i;

  for (i = 0; act[i].name != NULL; i++) {
    if (act[i].action == action)
      return (act[i].name);
  }

  (void) snprintf(buf, size, "<unknown action 0x%x>", action);

  return (buf);
}

boolean_t
valid(const dtrace_recdesc_t *rec)
{
  dtrace_actkind_t action = rec->dtrd_action;

  switch (action) {
    case DTRACEACT_DIFEXPR:
    case DTRACEACT_SYM:
    case DTRACEACT_MOD:
    case DTRACEACT_USYM:
    case DTRACEACT_UMOD:
    case DTRACEACT_UADDR:
      return (B_TRUE);

    default:
      return (B_FALSE);
  }
}

SV *
record(SV *self, const dtrace_recdesc_t *rec, caddr_t addr)
{
  CTX                 *ctx;
  SV                 **svp;
  dtrace_hdl_t        *dtp;
  HV                  *hash = (HV *)SvRV(self);

  svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  }

  switch (rec->dtrd_action) {
    case DTRACEACT_DIFEXPR:
      switch (rec->dtrd_size) {
        case sizeof(uint64_t):
          return (newSViv(*((int64_t *)addr)));

        case sizeof(uint32_t):
          return (newSViv(*((int32_t *)addr)));

        case sizeof(uint16_t):
          return (newSViv(*((int16_t *)addr)));

        case sizeof(uint8_t):
          return (newSViv(*((int8_t *)addr)));

        default:
          return (newSVpv((const char *)addr,0));
      }

    case DTRACEACT_SYM:
    case DTRACEACT_MOD:
    case DTRACEACT_USYM:
    case DTRACEACT_UMOD:
    case DTRACEACT_UADDR:
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("stop: No valid DTrace handle!");
      }

      char buf[2048], *tick, *plus;

      buf[0] = '\0';

      if (DTRACEACT_CLASS(rec->dtrd_action) == DTRACEACT_KERNEL) {
        uint64_t pc = ((uint64_t *)addr)[0];
        dtrace_addr2str(dtp, pc, buf, sizeof(buf) - 1);
      } else {
        uint64_t pid = ((uint64_t *)addr)[0];
        uint64_t pc  = ((uint64_t *)addr)[1];
        dtrace_uaddr2str(dtp, pid, pc, buf, sizeof(buf) - 1);
      }

      if (rec->dtrd_action == DTRACEACT_MOD ||
          rec->dtrd_action == DTRACEACT_UMOD) {
        /*
         * If we're looking for the module name, we'll
         * return everything to the left of the left-most
         * tick -- or "<undefined>" if there is none.
         */
        if ((tick = strchr(buf, '`')) == NULL)
          return (newSVpv("<unknown>",0));

        *tick = '\0';
      } else if (rec->dtrd_action == DTRACEACT_SYM ||
                 rec->dtrd_action == DTRACEACT_USYM) {
        /*
         * If we're looking for the symbol name, we'll
         * return everything to the left of the right-most
         * plus sign (if there is one).
         */
        if ((plus = strrchr(buf, '+')) != NULL)
          *plus = '\0';
      }

      return (newSVpv(buf,0));
  }

  return (newSViv(-1));
}

int
bufhandler(const dtrace_bufdata_t *bufdata, void *object)
{
  dSP;
  dtrace_probedata_t     *data = bufdata->dtbda_probe;
  const dtrace_recdesc_t *rec  = bufdata->dtbda_recdesc;
  HV  *probe_hash;
  SV  *probe_href;
  int  count;

  /* DTrace Consumer (dtc) will be passed in as 'object'  */
  CTX *dtc = (CTX *)object;
  SV  *callback = dtc->dtc_callback;

  if (rec == NULL || rec->dtrd_action != DTRACEACT_PRINTF)
    return( DTRACE_HANDLE_OK );

  ENTER;
  SAVETMPS;

  probe_hash = probedesc(data->dtpda_pdesc);

  /* Get the result of the probedesc() call, should be a href */
  probe_href = newRV_noinc( (SV *)probe_hash);

  /* Create a hashref for record */
  HV *rec_hash = newHV();
  hv_store(rec_hash, "data", strlen("data"), newSVpv(bufdata->dtbda_buffered,0), 0);

  SV *rec_href   = newRV_noinc( (SV *)rec_hash );

  /* Call the callback with the probe and record description */
  /* push the probe href and record href on the stack */
  PUSHMARK(SP);
  XPUSHs(probe_href);
  XPUSHs(rec_href);
  PUTBACK;

  count = call_sv(callback, G_DISCARD);

  SPAGAIN;

  /* This check shouldn't really be necessary, as we're discarding the
     result of the callback */
  if (count != 0)
    croak("bufhandler: failed to call callback!");

  FREETMPS;
  LEAVE;

  return( DTRACE_HANDLE_OK );
}

int
consume_callback_caller(const dtrace_probedata_t *data,
                        const dtrace_recdesc_t   *rec,
                        void                     *object)
{
  dSP;
  int count;
  HV  *probe_hash;
  SV  *probe_href;
  HV  *rec_hash;
  SV  *rec_href;
  CTX *ctx;
  SV  *callback;
  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
    /* TODO: We don't need the dtc_handler here - remove it */
    /*
    if (ctx->dtc_handle) {
      dtp = ctx->dtc_handle;
    } else {
      croak("consume_callback_caller: No valid DTrace handle!");
    }
    */
  }
  /* Extract the callback */
  callback = ctx->dtc_callback;

  ENTER;
  SAVETMPS;

  /* TODO: Is this even used anywhere?  We use the same thing in the
           call to probedesc() below, so there may be a way to factor this
           away. */
  dtrace_probedesc_t *pd = data->dtpda_pdesc;

  /* Call probedesc to get probe hashref  */
  probe_hash = probedesc(data->dtpda_pdesc);

  /* Get the result of the probedesc() call, should be a href */
  probe_href = newRV_noinc( (SV *)probe_hash);

  /* Handle case where the rec is NULL */
  if (rec == NULL) {
    /* Call the callback with *just* the probe description */
    PUSHMARK(SP);
    XPUSHs(probe_href);
    PUTBACK;

    count = call_sv(callback, G_DISCARD);

    SPAGAIN;

    /* This check shouldn't really be necessary, as we're discarding the
       result of the callback */
    if (count != 0)
      croak("consume_callback_caller: failed to call callback!");

    FREETMPS;
    LEAVE;
  
    return(DTRACE_CONSUME_NEXT);
  }

  if (!valid(rec)) {
    char errbuf[256];

    /* If this is a printf(), we defer to the bufhandler. */
    if (rec->dtrd_action == DTRACEACT_PRINTF)
      return (DTRACE_CONSUME_THIS);

    ctx->dtc_error =
      error("unsupported action %s in record for %s:%s:%s:%s\n",
                 action(rec, errbuf, sizeof(errbuf)),
                 pd->dtpd_provider, pd->dtpd_mod,
                 pd->dtpd_func, pd->dtpd_name);
    return (DTRACE_CONSUME_ABORT);
  }

  rec_hash = newHV();

  hv_store(rec_hash, "data", strlen("data"),
           record((SV *)object, rec, data->dtpda_data), 0);
 
  rec_href   = newRV_noinc((SV *)rec_hash);

  PUSHMARK(SP);
  /* push the probe_href and record_href onto the stack for the callback
   * to pick up */
  XPUSHs(probe_href);
  XPUSHs(rec_href);
  PUTBACK;

  count = call_sv(callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("consume_callback_caller: FAIL!\n");

  /* TODO: Pop something off the stack here? */

  FREETMPS;
  LEAVE;

  return(DTRACE_CONSUME_THIS);
}

/*
 * Caching the quantized ranges improves performance substantially if the
 * aggregations have many disjoint keys.
 * At present we only cache a single aggregation variable.
 * Programs that use more than one aggregation variable may see significant
 * degredation in performance.
 * TODO: Allow the cache to operate on multiple aggregation variables
 */
AV *
ranges_cached(dtrace_aggvarid_t varid, void *object)
{
  CTX *ctx;

  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  } else {
    croak("ranges_cached: No DTrace Consumer context!");
  }

  if (varid == ctx->dtc_ranges_varid)
    return (ctx->dtc_ranges);

  /* If we fall through to here, the aggregation variable is not cached */
  return (NULL);
}

AV *
ranges_cache(dtrace_aggvarid_t varid, AV *ranges, void *object)
{
  CTX *ctx;

  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  } else {
    croak("ranges_cache: No DTrace Consumer context!");
  }

  /* Free existing context/object instance specific dtc_ranges */
  if (ctx->dtc_ranges != NULL) {
    av_undef(ctx->dtc_ranges);
  }

  ctx->dtc_ranges       = ranges;
  ctx->dtc_ranges_varid = varid;

  return (ranges);
}

AV *
ranges_quantize(dtrace_aggvarid_t varid, void *object)
{
  int64_t   min, max;
  AV       *ranges;
  int       i;
  CTX      *ctx;

  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  } else {
    croak("ranges_quantize: No DTrace Consumer context!");
  }

  /* Short circuit this, if we've cached this data already */
  if ((ranges = ranges_cached(varid,object)) != NULL)
    return (ranges);

  ranges = newAV();
  /* Extend the array to the size we need for our buckets */
  /* av_fill(ranges, DTRACE_QUANTIZE_NBUCKETS - 1); */

  for (i = 0; i < DTRACE_QUANTIZE_NBUCKETS; i++) {
    AV *temp;
    SV *temp_aref;

    if (i < DTRACE_QUANTIZE_ZEROBUCKET) {
      /*
       * If we're less than the zero bucket, our range extends from
       * negative infinity through to the beginning of our zeroth
       * bucket.
       */ 
      min = i > 0 ? DTRACE_QUANTIZE_BUCKETVAL(i - 1) + 1 : INT64_MIN;
      max = DTRACE_QUANTIZE_BUCKETVAL(i);
    } else if (i == DTRACE_QUANTIZE_ZEROBUCKET) {
      min = max = 0;
    } else {
      min = DTRACE_QUANTIZE_BUCKETVAL(i);
      max = i < DTRACE_QUANTIZE_NBUCKETS - 1 ?
              DTRACE_QUANTIZE_BUCKETVAL(i + 1) - 1 :
              INT64_MAX;
    }

    temp = newAV();
    av_push( temp, newSViv(min) );
    av_push( temp, newSViv(max) );
    /* Take a reference to the array we just created */
    temp_aref = newRV_noinc( (SV *)temp );

    /* And push it on the ranges array, presumably at the same index as 'i' */
    av_push( ranges, temp_aref );
  }

  return (ranges_cache(varid, ranges, object));
}

AV *
ranges_lquantize(dtrace_aggvarid_t varid, const uint64_t arg, void *object)
{
  int64_t   min, max;
  AV       *ranges;
  int32_t   base;
  uint16_t  step, levels;
  int       i;
  CTX      *ctx;

  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  } else {
    croak("ranges_lquantize: No DTrace Consumer context!");
  }

  /* Short circuit this, if we've cached this data already */
  if ((ranges = ranges_cached(varid,object)) != NULL)
    return (ranges);

  base   = DTRACE_LQUANTIZE_BASE(arg);
  step   = DTRACE_LQUANTIZE_STEP(arg);
  levels = DTRACE_LQUANTIZE_LEVELS(arg);

  ranges = newAV();
  /* Extend the array to the size we need for lquantize */
  /* av_fill(ranges, levels + 2 - 1); */

  for (i = 0; i <= levels + 1; i++) {
    AV *temp;
    SV *temp_aref;

    min = i == 0     ? INT64_MIN : base + ((i - 1) * step);
    max = i > levels ? INT64_MAX : base + (i * step) - 1;

    temp = newAV();
    av_push( temp, newSViv(min) );
    av_push( temp, newSViv(max) );
    /* Take a reference to the array we just created */
    temp_aref = newRV_noinc( (SV *)temp );

    /* And push it on the ranges array, presumably at the same index as 'i' */
    av_push( ranges, temp_aref );
  }

  return (ranges_cache(varid, ranges, object));
}

AV *
ranges_llquantize(dtrace_aggvarid_t varid, const uint64_t arg, int nbuckets,
                  void *object)
{
  int64_t   value = 1, next, step;
  AV       *ranges;
  int       bucket = 0, order;
  uint16_t  factor, low, high, nsteps;

  CTX      *ctx;

  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  } else {
    croak("ranges_lquantize: No DTrace Consumer context!");
  }

  /* Short circuit this, if we've cached this data already */
  if ((ranges = ranges_cached(varid,object)) != NULL)
    return (ranges);

  factor = DTRACE_LLQUANTIZE_FACTOR(arg);
  low    = DTRACE_LLQUANTIZE_LMAG(arg);   /* was ..._LOW */
  high   = DTRACE_LLQUANTIZE_HMAG(arg);   /* was ..._HIGH */
  nsteps = DTRACE_LLQUANTIZE_STEPS(arg);  /* was ..._NSTEP */

  ranges = newAV();
  /* Extend the array to the size we need for llquantize */
  /*  av_fill(ranges, nbuckets - 1); */

  for (order = 0; order < low; order++)
    value *= factor;

  AV *temp;
  SV *temp_aref;

  temp = newAV();
  av_push( temp, newSViv(0) );
  av_push( temp, newSViv(value - 1) );

  /* Take a reference to the array we just created */
  temp_aref = newRV_noinc( (SV *)temp );

  /* And insert it into ranges array, at the right bucket */
  if (av_store(ranges, bucket, temp_aref) == 0) {
    SvREFCNT_dec(temp_aref);
    warn("ranges_llquantize: Failed to store first bucket in range");
  }

  bucket++;

  next = value * factor;
  step = next > nsteps ? next / nsteps : 1;

  while (order <= high) {
    temp = newAV();
    av_push( temp, newSViv(value) );
    av_push( temp, newSViv(value + step - 1) );

    /* Take a reference to the array we just created */
    temp_aref = newRV_noinc( (SV *)temp );

    /* And insert it into ranges array, at the right bucket */
    if (av_store(ranges, bucket, temp_aref) == 0) {
      SvREFCNT_dec(temp_aref);
      warn("ranges_llquantize: Failed to store intermediate buckets in range");
    }

    bucket++;

    if ((value += step) != next)
      continue;

    next = value * factor;
    step = next > nsteps ? next / nsteps : 1;
    order++;
  }

  temp = newAV();
  av_push( temp, newSViv(value) );
  av_push( temp, newSViv(INT64_MAX) );

  /* Take a reference to the array we just created */
  temp_aref = newRV_noinc( (SV *)temp );

  /* And insert it into ranges array, at the right bucket */
  if (av_store(ranges, bucket, temp_aref) == 0) {
    SvREFCNT_dec(temp_aref);
    warn("ranges_llquantize: Failed to store last bucket in range");
  }

  if (bucket + 1 != nbuckets)
    croak("ranges_llquantize: bucket count off");

  return (ranges_cache(varid, ranges, object));
}

int
aggwalk_callback_caller(const dtrace_aggdata_t *agg, void *object)
{
  dSP;
  CTX *ctx;
  HV  *self_hash = (HV *)SvRV((SV *)object);
  SV  **svp      = hv_fetchs( self_hash, "_my_instance_ctx", FALSE );
  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  }
  
  /* Extract the callback */
  SV  *callback  = ctx->dtc_callback;

  const dtrace_aggdesc_t *aggdesc = agg->dtada_desc;
  const dtrace_recdesc_t *aggrec;
  SV  *id;
  SV  *val;
  AV  *key;
  char errbuf[256];
  int  i;
  int  count;

  if ( svp && SvOK(*svp) ) {
    ctx = (CTX *)SvIV(*svp);
  }

  ENTER;
  SAVETMPS;

  /* Put the id in an SV at this point, after the SAVETMPS */
  id = newSViv(aggdesc->dtagd_varid);

  /*
   * We expect to have both a variable ID and an aggregation value here;
   * if we have fewer than two records, something is deeply wrong.
   */
  if (aggdesc->dtagd_nrecs < 2)
    croak("aggwalk_callback_caller: Less than 2 agg records!");

  /* Create a Perl array to hold the keys */
  key = newAV();
  av_fill( key, aggdesc->dtagd_nrecs - 2 - 1);

  for (i = 1; i < aggdesc->dtagd_nrecs - 1; i++) {
    const dtrace_recdesc_t *rec = &aggdesc->dtagd_rec[i];
    caddr_t addr = agg->dtada_data + rec->dtrd_offset;

    if (!valid(rec)) {
      /* TODO: Cannot just croak here - need to use error() call
               Guess that needs to be non-fatal too...
       */
      croak("Unsupported action %s as key #%d in aggregation \"%s\"\n",
            action(rec, errbuf, sizeof(errbuf)), i, aggdesc->dtagd_name);
      return (DTRACE_AGGWALK_ERROR);
    }

    SV *key_record = record(object, rec, addr);
    if (av_store(key, i - 1, key_record) == 0) {
      SvREFCNT_dec(key_record);
      warn("aggwalk_callback_caller: failed to store key record");
    }
  }

  aggrec = &aggdesc->dtagd_rec[aggdesc->dtagd_nrecs - 1];

  switch (aggrec->dtrd_action) {
    case DTRACEAGG_COUNT:
    case DTRACEAGG_MIN:
    case DTRACEAGG_MAX:
    case DTRACEAGG_SUM:
      {
        caddr_t addr = agg->dtada_data + aggrec->dtrd_offset;

        assert(aggrec->dtrd_size == sizeof (uint64_t));
        val = newSViv(*((int64_t *)addr));
        break;
      }

    case DTRACEAGG_AVG:
      {
        const int64_t *data =
          (int64_t *)(agg->dtada_data + aggrec->dtrd_offset);

        assert(aggrec->dtrd_size == sizeof (uint64_t) * 2);
        val = newSVnv(data[1] / (double)data[0]);
        break;
      }

    case DTRACEAGG_QUANTIZE:
      {
        AV *quantize = newAV();
        const int64_t *data =
          (int64_t *)(agg->dtada_data + aggrec->dtrd_offset);
        AV *ranges,
           *datum;
        SV *temp_aref;
        int i, j = 0;
        int64_t   min, max;

        ranges = newAV();
        for (i = 0; i < DTRACE_QUANTIZE_NBUCKETS; i++) {
          AV *temp;
          SV *temp_aref;
          if (i < DTRACE_QUANTIZE_ZEROBUCKET) {
            /*
             * If we're less than the zero bucket, our range extends from
             * negative infinity through to the beginning of our zeroth
             * bucket.
             */ 
            min = i > 0 ? DTRACE_QUANTIZE_BUCKETVAL(i - 1) + 1 : INT64_MIN;
            max = DTRACE_QUANTIZE_BUCKETVAL(i);
          } else if (i == DTRACE_QUANTIZE_ZEROBUCKET) {
            min = max = 0;
          } else {
            min = DTRACE_QUANTIZE_BUCKETVAL(i);
            max = i < DTRACE_QUANTIZE_NBUCKETS - 1 ?
              DTRACE_QUANTIZE_BUCKETVAL(i + 1) - 1 :
              INT64_MAX;
          }

          temp = newAV();
          av_push( temp, newSViv(min) );
          av_push( temp, newSViv(max) );
          /* Take a reference to the array we just created */
          temp_aref = newRV( (SV *)temp );

          /* And push it on the ranges array, presumably at the same index as 'i' */
          av_push( ranges, temp_aref );
        }

        for (i = 0; i < DTRACE_QUANTIZE_NBUCKETS; i++) {
          if (!data[i])
            continue;

          datum = newAV();
          /* TODO: Check that av_fetch() returns non-NULL before dereferencing it */
          av_push( datum, *(av_fetch(ranges, i, 0 )) );
          av_push( datum, newSViv(data[i]) );

          /* Take a reference to datum and store in quantize */

          temp_aref = newRV( (SV *)datum );

          if (av_store(quantize, j++, temp_aref) == 0) {
            SvREFCNT_dec(temp_aref);
            warn("Failed to store quantize data");
          }
        }

        val = newRV_noinc( (SV *) quantize );
        break;
      }

    case DTRACEAGG_LQUANTIZE:
    case DTRACEAGG_LLQUANTIZE:
      {
        AV *lquantize = newAV();
        const int64_t *data =
          (int64_t *)(agg->dtada_data + aggrec->dtrd_offset);
        AV *ranges, *datum;
        SV *temp_aref;
        int i, j = 0;
        int64_t   min, max;

        uint64_t arg = *data++;
        int levels   = (aggrec->dtrd_size / sizeof (uint64_t)) - 1;
        int nbuckets = levels;

        if (aggrec->dtrd_action == DTRACEAGG_LQUANTIZE) {
          int32_t   base;
          uint16_t  step, levels;

          base   = DTRACE_LQUANTIZE_BASE(arg);
          step   = DTRACE_LQUANTIZE_STEP(arg);
          levels = DTRACE_LQUANTIZE_LEVELS(arg);

          ranges = newAV();

          for (i = 0; i <= levels + 1; i++) {
            AV *temp;
            SV *temp_aref;

            min = i == 0     ? INT64_MIN : base + ((i - 1) * step);
            max = i > levels ? INT64_MAX : base + (i * step) - 1;

            temp = newAV();
            av_push( temp, newSViv(min) );
            av_push( temp, newSViv(max) );
            /* Take a reference to the array we just created */
            temp_aref = newRV( (SV *)temp );

            /* And push it on the ranges array, presumably at the same index as 'i' */
            av_push( ranges, temp_aref );
          }
        } else {
          int64_t   value = 1, next, step;
          int       bucket = 0, order;
          uint16_t  factor, low, high, nsteps;

          factor = DTRACE_LLQUANTIZE_FACTOR(arg);
          low    = DTRACE_LLQUANTIZE_LMAG(arg);   /* was ..._LOW */
          high   = DTRACE_LLQUANTIZE_HMAG(arg);   /* was ..._HIGH */
          nsteps = DTRACE_LLQUANTIZE_STEPS(arg);  /* was ..._NSTEP */

          ranges = newAV();

          for (order = 0; order < low; order++)
            value *= factor;

          AV *temp;
          SV *temp_aref;

          temp = newAV();
          av_push( temp, newSViv(0) );
          av_push( temp, newSViv(value - 1) );

          /* Take a reference to the array we just created */
          temp_aref = newRV_noinc( (SV *)temp );

          /* And insert it into ranges array, at the right bucket */
          if (av_store(ranges, bucket, temp_aref) == 0) {
            SvREFCNT_dec(temp_aref);
            warn("ranges_llquantize: Failed to store first bucket in range");
          }

          bucket++;

          next = value * factor;
          step = next > nsteps ? next / nsteps : 1;

          while (order <= high) {
            temp = newAV();
            av_push( temp, newSViv(value) );
            av_push( temp, newSViv(value + step - 1) );

            /* Take a reference to the array we just created */
            temp_aref = newRV( (SV *)temp );

            /* And insert it into ranges array, at the right bucket */
            if (av_store(ranges, bucket, temp_aref) == 0) {
              SvREFCNT_dec(temp_aref);
              warn("ranges_llquantize: Failed to store intermediate buckets in range");
            }

            bucket++;

            if ((value += step) != next)
              continue;

            next = value * factor;
            step = next > nsteps ? next / nsteps : 1;
            order++;
          }

          temp = newAV();
          av_push( temp, newSViv(value) );
          av_push( temp, newSViv(INT64_MAX) );

          /* Take a reference to the array we just created */
          temp_aref = newRV_noinc( (SV *)temp );

          /* And insert it into ranges array, at the right bucket */
          if (av_store(ranges, bucket, temp_aref) == 0) {
            SvREFCNT_dec(temp_aref);
            warn("ranges_llquantize: Failed to store last bucket in range");
          }

          if (bucket + 1 != nbuckets)
            croak("ranges_llquantize: bucket count off");
        }

        for (i = 0; i < levels; i++) {
          if (!data[i])
            continue;

          datum = newAV();
          SV **elem = av_fetch(ranges, i, 0);
          if (elem == NULL) {
            warn("Unable to fetch element %d from ranges for quantize",i);
            /* Tack on an undev instead */
            av_push( datum, newSV( 0 ) );
          } else {
            av_push( datum, *(av_fetch( ranges, i, 0 )) );
          }
          av_push( datum, newSViv(data[i]) );

          /* Take a reference to datum and store in quantize */
          temp_aref = newRV( (SV *)datum );

          if (av_store(lquantize, j++, temp_aref) == 0) {
            SvREFCNT_dec(temp_aref);
            warn("Failed to store quantize data");
          }
        }

        val = newRV_noinc( (SV *) lquantize );
        break;
      }

    default:
      ctx->dtc_error = error("unsupported aggregating action "
          " %s in aggregation \"%s\"\n",
            action(aggrec, errbuf, sizeof (errbuf)),
            aggdesc->dtagd_name);
      return (DTRACE_AGGWALK_ERROR);
  }

  SV *key_aref = newRV_noinc( (SV *) key );
  /* Put the right items on the stack */
  PUSHMARK(SP);
  XPUSHs(sv_2mortal( id ));
  XPUSHs(sv_2mortal( key_aref ));
  XPUSHs(sv_2mortal( val ));
  PUTBACK;

  /* Call the callback */

  count = call_sv(callback, G_DISCARD);

  SPAGAIN;

  /* This check shouldn't really be necessary, as we're discarding the
     result of the callback */
  if (count != 0)
    croak("aggwalk_callback_caller: failed to call callback!");

  FREETMPS;
  LEAVE;
 
  return (DTRACE_AGGWALK_REMOVE);
}


/* And now the XS code, for C functions we want to access directly from Perl */

MODULE = DTrace::Consumer              PACKAGE = DTrace::Consumer

# XS code

PROTOTYPES: ENABLED

SV *
new( const char *class )
  PREINIT:
    dtrace_hdl_t *dtp;
    CTX* ctx = (CTX *)calloc( 1, sizeof(CTX) );
  CODE:
    int  err;
    /* Create a hash */
    HV* hash = newHV();

    /* TODO: initialize dtc_ranges to NULL */

    /* Create DTrace Handle / Context */
    /* NOTE: DTRACE_VERSION comes from dtrace.h */
    /*       This was written when it was version 3 */
    if ((dtp = dtrace_open(DTRACE_VERSION, 0, &err)) == NULL)
      croak("Unable to create a DTrace handle: %s",
            dtrace_errmsg(NULL,err));

    ctx->dtc_handle = dtp;

    /*
     * Set buffer size and aggregation buffer size to a reasonable
     * size of 512K (for systems with many CPUs).
     */
    (void)dtrace_setopt(dtp, "bufsize", "512k");
    (void)dtrace_setopt(dtp, "aggsize", "512k");

    if ((dtrace_handle_buffered(dtp, bufhandler, ctx)) == -1)
      croak("dtrace_handle_buffered failed: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));

    /* Store the pointer to the instance context struct in the hash
     * It's private, so if a user plays with it, everything breaks.
     */
    hv_store(hash, "_my_instance_ctx", strlen("_my_instance_ctx"),
             newSViv( PTR2IV(ctx) ), FALSE);

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

void
setopt(SV *self, char *option, ...)
  PREINIT:
    HV           *hash;
    CTX          *ctx;
    SV           **svp;
    int           rval;
    dtrace_hdl_t *dtp;
    char         *my_option;
    char         *value;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("setopt: No valid DTrace handle!");
      }
    }

    /* Die early if too many arguments specified */
    if (items > 3) {
      croak("Too many arguments specified");
    }
    /*  This should never get hit - the XS level should emit a Usage: message
     *  instead and dire on it's own */
    if (items == 1) {
      croak("setopt: requires an option and possibly a value for it");
    }
    /* We've got at least an option specified here; we test for >= 2 because
     * some options don't have associated values, ever, and others do */
    if (items >= 2) {
      if (! SvPOK( ST(1) )) {
        croak("setopt: Option must be a string");
      }
      my_option = (char *)SvPV_nolen(ST(1));
    }
    /* An attempt to specify a value for the option above has been made - it too
     * must be in string format */
    if (items == 3) {
      if (SvPOK( ST(2) )) {
        value = (char *)(SvPV_nolen(ST(2)));
      } else {
        croak("setopt: Value must be a string");
      }
      rval = dtrace_setopt(dtp, my_option, value);
    } else {
      rval = dtrace_setopt(dtp, my_option, NULL);
    }

    if (rval != 0) {
      croak("Couldn't set option '%s': %s", my_option,
             dtrace_errmsg(dtp, dtrace_errno(dtp)));
    }


void
strcompile(SV *self, ... )
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
    dtrace_prog_t      *dp;
    dtrace_proginfo_t   info;
    char               *program;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("strcompile: No valid DTrace handle!");
      }
    }

    /* If less than 2 args passed in, we're missing a program */
    if (items < 2)
      croak("strcompile: Expected a program!");

    if (! SvPOK( ST(1) )) {
      croak("strcompile: Program must be a string");
    }
    program = (char *)SvPV_nolen(ST(1));

    if ((dp = dtrace_program_strcompile(dtp, program,
              DTRACE_PROBESPEC_NAME, 0, 0, NULL)) == NULL)
      croak("Couldn't compile '%s': %s", program,
            dtrace_errmsg(dtp, dtrace_errno(dtp)));

    if (dtrace_program_exec(dtp, dp, &info) == -1)
      croak("Couldn't execute '%s': %s", program,
            dtrace_errmsg(dtp, dtrace_errno(dtp)));


void
go(SV* self)
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("go: No valid DTrace handle!");
      }
    }

    if (dtrace_go(dtp) == -1)
      croak("Couldn't enable tracing: %s",
            dtrace_errmsg(dtp, dtrace_errno(dtp)));

void
stop(SV* self)
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("stop: No valid DTrace handle!");
      }
    }

    if (dtrace_stop(dtp) == -1)
      croak("Couldn't disable tracing: %s",
            dtrace_errmsg(dtp, dtrace_errno(dtp)));


SV *
consume(SV *self, SV *callback )
  PREINIT:
    HV                  *hash;
    CTX                 *ctx;
    SV                  **svp;
    dtrace_hdl_t        *dtp;
    dtrace_workstatus_t  status;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("stop: No valid DTrace handle!");
      }
    }

    /* Set up callback and it's args */
    /* Take a copy of the callback into our self*/
    if (ctx->dtc_callback == (SV*)NULL) {
      /* First time through, so create a new SV */
      ctx->dtc_callback = newSVsv(callback);
    } else {
      SvSetSV(ctx->dtc_callback, callback);
    }

    status = dtrace_work(dtp, NULL, NULL, consume_callback_caller, (void *)self);

    /* TODO: Need to make sure ctx->dtc_error is *defined* */
    if (status == -1 && ctx->dtc_error) {
      RETVAL = ctx->dtc_error;
    } else {
      /* Need to return undef in this case */
      XSRETURN_UNDEF;
    }
  OUTPUT: RETVAL

SV *
aggclear(SV *self)
  PREINIT:
    HV             *hash;
    CTX            *ctx;
    SV             **svp;
    dtrace_hdl_t   *dtp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("stop: No valid DTrace handle!");
      }
    }

    if (dtrace_status(dtp) == -1)
      croak("aggclear: Couldn't get status: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));

    dtrace_aggregate_clear(dtp);

    /* Do we want to return undef, or 1 for success ? */
    XSRETURN_UNDEF;

SV *
aggmin(void)
  CODE:
    SV *min = newSViv(INT64_MIN);
    RETVAL = min;
  OUTPUT: RETVAL

SV *
aggmax(void)
  CODE:
    SV *max = newSViv(INT64_MAX);
    RETVAL = max;
  OUTPUT: RETVAL

SV *
aggwalk(SV *self, SV *callback )
  PREINIT:
    HV             *hash;
    CTX            *ctx;
    SV             **svp;
    dtrace_hdl_t   *dtp;
    int             rval;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("stop: No valid DTrace handle!");
      }
    }

    ctx->dtc_error = NULL;  /* Clean up first */

    if (dtrace_status(dtp) == -1)
      croak("aggwalk: Couldn't get status: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));

    if (dtrace_aggregate_snap(dtp) == -1)
      croak("aggwalk: Couldn't snap aggregate: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));

    /* Set up callback and it's args */
    /* Take a copy of the callback into our self*/
    if (ctx->dtc_callback == (SV*)NULL) {
      /* First time through, so create a new SV */
      ctx->dtc_callback = newSVsv(callback);
    } else {
      SvSetSV(ctx->dtc_callback, callback);
    }

    rval = dtrace_aggregate_walk(dtp, aggwalk_callback_caller, (void *)self);

    /*
     * Flush the ranges cache; the ranges will go out of scope when the destructor
     * for our object is called, and we cannot be left holding references.
     */
    ranges_cache(DTRACE_AGGVARIDNONE, NULL, (void *)self);

    if (rval == -1) {
      if (ctx->dtc_error != NULL)
        RETVAL = ctx->dtc_error;

      croak("aggwalk: Couldn't walk aggregate: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));
    }

    /* Do we want to return undef, or 1 for success ? */
    XSRETURN_UNDEF;
  OUTPUT: RETVAL

void
DESTROY(SV *self)
  PREINIT:
    HV  *hash;
    CTX *ctx;
    SV  **svp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle)
        dtrace_close(ctx->dtc_handle);
      free(ctx);
    }
    /* TODO: Eliminate dtc_ranges, if it exists */



