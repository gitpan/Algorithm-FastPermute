#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

void
permute_engine(AV* av, SV** array, I32 level, I32 len, SV*** tmparea, OP* callback)
{
	SV** copy    = tmparea[level];
	int  index   = level;
	bool calling = (index + 1 == len);
	SV*  tmp;
	
	Copy(array, copy, len, SV*);
	
	if (calling)
	    AvARRAY(av) = copy;

	do {
		if (calling) {
		    PL_op = callback;
		    CALLRUNOPS(aTHX);
		}
		else {
		    permute_engine(av, copy, level + 1, len, tmparea, callback);
		}
		if (index != 0) {
			tmp = copy[index];
			copy[index] = copy[index - 1];
			copy[index - 1] = tmp;
		}
	} while (index-- > 0);
}


MODULE = Algorithm::FastPermute		PACKAGE = Algorithm::FastPermute		

void
permute(callback_sv, array_sv)
SV* callback_sv;
SV* array_sv;
  PROTOTYPE: &\@
  PREINIT:
    AV*           array;
    CV*           callback;
    I32           x;
    I32           len;
    SV***         tmparea;
    SV**          array_array;
    U32           array_flags;
    SSize_t       array_fill;
    SV**          copy = 0;  /* Non-magical SV list for magical array */
    PERL_CONTEXT* cx;
    I32           gimme = G_VOID;  /* We call our callback in VOID context */
    I32           saved_cxstack_ix;
    PERL_CONTEXT* saved_cxstack;
    bool          old_catch;
  PPCODE:
    if (!SvROK(callback_sv) || SvTYPE(SvRV(callback_sv)) != SVt_PVCV)
        Perl_croak(aTHX_ "Callback is not a CODE reference");
    if (!SvROK(array_sv)    || SvTYPE(SvRV(array_sv))    != SVt_PVAV)
        Perl_croak(aTHX_ "Array is not an ARRAY reference");
    
    callback = (CV*)SvRV(callback_sv);
    array    = (AV*)SvRV(array_sv);
    len      = 1 + av_len(array);
    
    if (SvREADONLY(array))
        Perl_croak(aTHX_ "Can't permute a read-only array");
    
    if (len == 0) {
        /* Should we warn here? */
        return;
    }
    
    array_array = AvARRAY(array);
    array_flags = SvFLAGS(array);
    array_fill  = AvFILLp(array);

    /* Magical array. Realise it temporarily. */
    if (SvRMAGICAL(array)) {
        copy = (SV**) malloc (len * sizeof *copy);
        for (x=0; x < len; x++) {
            SV **svp = av_fetch(array, x, FALSE);
            copy[x] = (svp) ? SvREFCNT_inc(*svp) : &PL_sv_undef;
        }
        SvRMAGICAL_off(array);
        AvARRAY(array) = copy;
        AvFILLp(array) = len - 1;
    }
    
    SvREADONLY_on(array);  /* Can't change the array during permute */ 
    
    /* Allocate memory for the engine to scribble on */   
    tmparea = (SV***) malloc( (len+1) * sizeof *tmparea);
    for (x = len; x >= 0; x--)
        tmparea[x]  = malloc(len * sizeof **tmparea);
    
    /* Set up the context for the callback */
    SAVESPTR(CvROOT(callback)->op_ppaddr);
    CvROOT(callback)->op_ppaddr = PL_ppaddr[OP_NULL];  /* Zap the OP_LEAVESUB */
    SAVESPTR(PL_curpad);
    PL_curpad = AvARRAY((AV*)AvARRAY(CvPADLIST(callback))[1]);
    SAVETMPS;
    SAVESPTR(PL_op);

    saved_cxstack    = cxstack;
    saved_cxstack_ix = cxstack_ix;
    PUSHBLOCK(cx, CXt_NULL, SP);  /* make a pseudo block */
    cxstack   += cxstack_ix;      /* deny the existence of anything outside */
    cxstack_ix = 0;
    old_catch = CATCH_GET;
    CATCH_SET(TRUE);
    
    permute_engine(array, AvARRAY(array), 0, len, tmparea, CvSTART(callback));
    
    CATCH_SET(old_catch);
    /* PerlIO_stdoutf("Back from engine\n"); */
    dounwind(-1);
    cxstack    = saved_cxstack;
    cxstack_ix = saved_cxstack_ix;
   
    for (x = len - 1; x >= 0; x--) free(tmparea[x]);
    free(tmparea);
    if (copy) {
        for (x=0; x < len; x++) SvREFCNT_dec(copy[x]);
        free(copy);
    }
    
    AvARRAY(array) = array_array;
    SvFLAGS(array) = array_flags;
    AvFILLp(array) = array_fill;
