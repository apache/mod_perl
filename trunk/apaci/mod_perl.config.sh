##
##  mod_perl.config.sh -- mod_perl configuration transformation script
##  Written by Ralf S. Engelschall <rse@apache.org>
##

DIFS=' 	
'

#   defaults
config_file='mod_perl.config'
build_type='OBJ'
display_prefix=''
tmpfile1=".tmp.$$.1"
tmpfile2=".tmp.$$.2"

#
#   parse argument line
#
prev=''
OIFS="$IFS" IFS="$DIFS"
for option
do
    if [ ".$prev" != . ]; then
        eval "$prev=\$option"
        prev=""
        continue
    fi
    case "$option" in
        -*=*) optarg=`echo "$option" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
           *) optarg='' ;;
    esac
    case "$option" in
        --config-file=*)     config_file="$optarg"    ;;
        --config-override=*) config_override="$optarg" ;;
        --build-type=*)      build_type="$optarg"     ;;
        --display-prefix=*)  display_prefix="$optarg" ;;
        * ) echo "$0:Error: invalid option '$option'" 1>&2; exit 1 ;;
    esac
done
IFS="$OIFS"
if [ ".$prev" != . ]; then
    echo "$0:Error: missing argument to --`echo $prev | sed 's/_/-/g'`" 1>&2
    exit 1
fi


#
#   import parameters from config file into
#   own namespace to avoid conflicts with src/Configure
#
(cat $config_file; echo "$config_override" | sed -e 's:,[ 	]*:,:' | tr "," "\n") >$tmpfile1
vars="`egrep '^[A-Z0-9_]*[ 	]*=' $tmpfile1 | sed -e 's:^\([A-Z0-9_]*\).*:\1:'`"
OIFS="$IFS" IFS="$DIFS"
for var in $vars; do
    egrep "^${var}[ 	]*=" $tmpfile1 | tail -1 >$tmpfile2
    val="`sed -e 's:^[A-Z0-9_]*[ 	]*=[ 	]*::' <$tmpfile2`"
    eval "param_${var}=\"${val}\""
done
IFS="$OIFS"

#
#   verbose message
#
echo "$display_prefix id: mod_perl/$param_MOD_PERL_VERSION" 1>&2

#
#   determine Perl interpreter and version
#
perl_interp="$param_PERL"
if [ ".$perl_interp" = .DEFAULT ]; then
    if [ ".$PERL" != . ]; then
        perl_interp="$PERL"
    else 
        perl_interp=""
    fi
fi
if [ ".$perl_interp" = . ]; then
    OIFS=$IFS IFS=':'
    for my_dir in $PATH; do
        for my_exe in perl5 perl; do
            if test -f "$my_dir/$my_exe"; then
                if test -x "$my_dir/$my_exe"; then
                    perl_interp="$my_dir/$my_exe"
                    break 2
                fi
            fi
        done
    done
    IFS="$OIFS"
    perl_interp="`echo $perl_interp | sed -e 's://:/:'`"
fi
perl_version="`$perl_interp -e 'print $];'`"
os_version="`$perl_interp -e 'print $^O;'`"

#
#   verbose message
#
echo "$display_prefix id: Perl/$perl_version ($os_version) [$perl_interp]" 1>&2

#
#   determine build tools and flags  
#
perl_cc="`$perl_interp -MConfig -e 'print $Config{cc}'`"
perl_ccflags="`$perl_interp -MConfig -e 'print $Config{ccflags}'`"
perl_optimize="`$perl_interp -MConfig -e 'print $Config{optimize}'`"
perl_cccdlflags="`$perl_interp -MConfig -e 'print $Config{cccdlflags}'`"
perl_ld="`$perl_interp -MConfig -e 'print $Config{ld}'`"
perl_ldflags="`$perl_interp -MConfig -e 'print $Config{ldflags}'`"
perl_lddlflags="`$perl_interp -MConfig -e 'print $Config{lddlflags}'`"
cat >$tmpfile2 <<'EOT'
use Config;
my $ldopts = `$^X -MExtUtils::Embed -e ldopts -- -std @ARGV`;
$ldopts =~ s,(-bE:)(perl\.exp),$1$Config{archlibexp}/CORE/$2, if($^O eq "aix");
print $ldopts;
EOT
perl_libs="`$perl_interp $tmpfile2`"
perl_inc="`$perl_interp -MExtUtils::Embed -e perl_inc`"
perl_privlibexp="`$perl_interp -MConfig -e 'print $Config{privlibexp}'`"
perl_archlibexp="`$perl_interp -MConfig -e 'print $Config{archlibexp}'`"
perl_xsinit="$perl_interp -MExtUtils::Embed -e xsinit"
perl_xsubpp="$perl_interp ${perl_privlibexp}/ExtUtils/xsubpp -typemap ${perl_privlibexp}/ExtUtils/typemap"
perl_ar="`$perl_interp -MConfig -e 'print $Config{ar}'`"
perl_ranlib=`$perl_interp -MConfig -e 'print $Config{ranlib}'`

#
#   determine static objects
#
perl_static_exts="$param_PERL_STATIC_EXTS"
perl_static_srcs="$param_PERL_STATIC_SRCS"
perl_static_objs="`echo $param_PERL_STATIC_SRCS | sed -e 's:\.c:.o:g'`"
perl_static_objs_pic="`echo $param_PERL_STATIC_SRCS | sed -e 's:\.c:.lo:g'`"

#
#   determine defines
#
perl_defs=''
perl_defs="$perl_defs -DMOD_PERL_VERSION=\\\"$param_MOD_PERL_VERSION\\\""
perl_defs="$perl_defs -DMOD_PERL_STRING_VERSION=\\\"mod_perl/$param_MOD_PERL_VERSION\\\""
OIFS="$IFS" IFS="$DIFS"
for hook in \
    DISPATCH CHILD_INIT CHILD_EXIT RESTART POST_READ_REQUEST TRANS HEADER_PARSER \
    ACCESS AUTHEN AUTHZ TYPE FIXUP LOG INIT CLEANUP STACKED_HANDLERS SECTIONS \
    METHOD_HANDLERS SSI TRACE; do
    eval "val=\$param_PERL_${hook}"
    if [ ".$val" = .no ]; then
        perl_defs="$perl_defs -DNO_PERL_${hook}=1"
    fi
done
IFS="$OIFS"

#
#   output information as Makefile parameters
#
echo "PERL=$perl_interp"
echo "PERL_CC=$perl_cc"
echo "PERL_OPTIMIZE=$perl_optimize"
echo "PERL_CCFLAGS=$perl_ccflags"
echo "PERL_CCCDLFLAGS=$perl_cccdlflags"
echo "PERL_DEFS=$perl_defs"
echo "PERL_INC=$perl_inc"
echo "PERL_LD=$perl_ld"
echo "PERL_LDFLAGS=$perl_ldflags"
echo "PERL_LDDLFLAGS=$perl_lddlflags"
echo "PERL_LIBS=$perl_libs"
echo "PERL_XSINIT=$perl_xsinit"
echo "PERL_XSUBPP=$perl_xsubpp"
echo "PERL_AR=$perl_ar"
echo "PERL_RANLIB=$perl_ranlib"
echo "PERL_STATIC_EXTS=$perl_static_exts"
echo "PERL_STATIC_SRCS=$perl_static_srcs"
echo "PERL_STATIC_OBJS=$perl_static_objs"
echo "PERL_STATIC_OBJS_PIC=$perl_static_objs_pic"

echo "PERL_SSI=$param_PERL_SSI"

#
#  cleanup
#
rm -f $tmpfile1 $tmpfile2

