#some handy debugging macros, hopefully you'll never need them
#some don't quite work, like dump_hv and hv_fetch, 
#where's the bloody manpage for .gdbinit syntax?

define thttpd
   run -X -d `pwd`/t
#   set $sv = perl_eval_pv("$Apache::ErrLog = '/tmp/mod_perl_error_log'",1)
end

define httpd
   run -X -d `pwd`
   set $sv = perl_eval_pv("$Apache::ErrLog = Apache->server_root_relative('logs/error_log')", 1)
   #printf "error_log = %s\n", ((XPV*) ($sv)->sv_any )->xpv_pv
end

define STpvx
   print ((XPV*) (Perl_stack_base [ax + ($arg0)] )->sv_any )->xpv_pv
end

define TOPs 
    print ((XPV*) (**sp)->sv_any )->xpv_pv
end

define curstash
   print ((XPVHV*) (curstash)->sv_any)->xhv_name
end

define defstash
   print ((XPVHV*) (defstash)->sv_any)->xhv_name
end

define curcopfile
   print ((XPV*) ((((XPVGV*)Perl_curcop->cop_filegv)->xgv_gp)->gp_sv)->sv_any)->xpv_pv
end

define SvPVX
print ((XPV*) ($arg0)->sv_any )->xpv_pv
end

define SvCUR
   print ((XPV*)  ($arg0)->sv_any )->xpv_cur 
end

define SvLEN
   print ((XPV*)  ($arg0)->sv_any )->xpv_len 
end

define SvEND
   print (((XPV*)  ($arg0)->sv_any )->xpv_pv + ((XPV*)($arg0)->sv_any )->xpv_cur) - 1
end

define SvSTASH
   print ((XPVHV*)((XPVMG*)($arg0)->sv_any )->xmg_stash)->sv_any->xhv_name
end

define SvTAINTED
   print ((($arg0)->sv_flags  & (0x00002000 |0x00004000 |0x00008000 ))  && Perl_sv_tainted ($arg0)) 
end

define SvTRUE
   print (	!$arg0	? 0	:    (($arg0)->sv_flags  & 0x00040000 ) 	?   ((Perl_Xpv  = (XPV*)($arg0)->sv_any ) &&	(*Perl_Xpv ->xpv_pv > '0' ||	Perl_Xpv ->xpv_cur > 1 ||	(Perl_Xpv ->xpv_cur && *Perl_Xpv ->xpv_pv != '0'))	? 1	: 0)	:	(($arg0)->sv_flags  & 0x00010000 ) 	? ((XPVIV*)  ($arg0)->sv_any )->xiv_iv  != 0	:   (($arg0)->sv_flags  & 0x00020000 ) 	? ((XPVNV*)($arg0)->sv_any )->xnv_nv  != 0.0	: Perl_sv_2bool ($arg0) ) 
end

define GvHV
   set $hv = (((((XPVGV*)($arg0)->sv_any ) ->xgv_gp) )->gp_hv) 
end

define GvSV
 print ((XPV*) ((((XPVGV*)($arg0)->sv_any ) ->xgv_gp) ->gp_sv )->sv_any )->xpv_pv
end

define GvNAME
   print (((XPVGV*)($arg0)->sv_any ) ->xgv_name)
end

define GvFILEGV
   print ((XPV*) ((((XPVGV*)$arg0->filegv)->xgv_gp)->gp_sv)->sv_any)->xpv_pv
end

define CvNAME
   print ((XPVGV*)(((XPVCV*)($arg0)->sv_any)->xcv_gv)->sv_any)->xgv_name
end

define CvSTASH
   print ((XPVHV*)(((XPVGV*)(((XPVCV*)($arg0)->sv_any)->xcv_gv)->sv_any)->xgv_stash)->sv_any)->xhv_name
end

define CvDEPTH
   print ((XPVCV*)($arg0)->sv_any )->xcv_depth 
end

define CvFILEGV
   print ((XPV*) ((((XPVGV*)((XPVCV*)($arg0)->sv_any )->xcv_filegv)->xgv_gp)->gp_sv)->sv_any)->xpv_pv
end

define SVOPpvx
   print ((XPV*) ( ((SVOP*)$arg0)->op_sv)->sv_any )->xpv_pv
end

define HvNAME
   print ((XPVHV*)$arg0->sv_any)->xhv_name
end

define HvKEYS
   print ((XPVHV*)  ($arg0)->sv_any)->xhv_keys
end

define AvFILL
   print ((XPVAV*)  ($arg0)->sv_any)->xav_fill
end

define dump_av
    set $n = ((XPVAV*)  ($arg0)->sv_any)->xav_fill
    set $i = 0
    while $i <= $n
        set $sv = *Perl_av_fetch($arg0, $i, 0)
        printf "[%u] -> `%s'\n", $i, ((XPV*) ($sv)->sv_any )->xpv_pv
        set $i = $i + 1
    end
end

define dump_hv
    set $n = ((XPVHV*)  ($arg0)->sv_any)->xhv_keys
    set $i = 0
    set $key = 0
    set $klen = 0
    Perl_hv_iterinit($arg0)
    while $i <= $n
        set $sv = Perl_hv_iternextsv($arg0, &$key, &$klen)
        printf "%s = `%s'\n", $key, ((XPV*) ($sv)->sv_any )->xpv_pv
        set $i = $i + 1
    end
end

define hv_fetch
   set $klen = strlen($arg1)
   set $sv = *Perl_hv_fetch($arg0, $arg1, $klen, 0)
   printf "%s = `%s'\n", $arg1, ((XPV*) ($sv)->sv_any )->xpv_pv
end

define hvINCval
   set $hv = (((((XPVGV*)(incgv)->sv_any)->xgv_gp))->gp_hv)
   set $klen = strlen($arg0)
   set $sv = *Perl_hv_fetch($hv, $arg0, $klen, 0)
   printf "%s = `%s'\n", $arg0, ((XPV*) ($sv)->sv_any )->xpv_pv
end

define dump_any
   set $sv = Perl_newSVpv("use Data::Dumper; Dumper \\",0)
   set $void = Perl_sv_catpv($sv, $arg0)
   set $dump = perl_eval_pv(((XPV*) ($sv)->sv_any )->xpv_pv, 1)
   printf "%s = `%s'\n", $arg0, ((XPV*) ($dump)->sv_any )->xpv_pv
end

define dump_any_rv
   set $rv = Perl_newRV((SV*)$arg0)
   set $rvpv = perl_get_sv("main::DumpAnyRv", 1)
   set $void = Perl_sv_setsv($rvpv, $rv)
   set $sv = perl_eval_pv("use Data::Dumper; Dumper $::DumpAnyRv",1)
   printf "`%s'\n", ((XPV*) ($sv)->sv_any )->xpv_pv
end

define sv_peek
   set $pv = Perl_sv_peek((SV*)$arg0)
   printf "%s\n", $pv
end

define caller
   set $sv = perl_eval_pv("scalar caller", 1)
   printf "caller = %s\n", ((XPV*) ($sv)->sv_any )->xpv_pv
end

define cluck
   set $sv = perl_eval_pv("Carp::cluck(); `tail '$Apache::ErrLog'`", 1)
   printf "%s\n", ((XPV*) ($sv)->sv_any )->xpv_pv
end
