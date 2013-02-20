/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"
#include "modperl_const.h"

typedef SV *(*constants_lookup)(pTHX_ const char *);
typedef const char ** (*constants_group_lookup)(const char *);

static void new_constsub(pTHX_ constants_lookup lookup,
                        HV *caller_stash, HV *stash,
                        const char *name)
{
    int name_len = strlen(name);
    GV **gvp = (GV **)hv_fetch(stash, name, name_len, TRUE);

    /* dont redefine */
    if (!isGV(*gvp) || !GvCV(*gvp)) {
        SV *val = (*lookup)(aTHX_ name);

#if 0
        Perl_warn(aTHX_  "newCONSTSUB(%s, %s, %s)\n",
                  HvNAME(stash), name, SvPV_nolen(val));
#endif

        newCONSTSUB(stash, (char *)name, val);
#ifdef GvSHARED
        GvSHARED_on(*gvp);
#endif
    }

    /* export into callers namespace */
    if (caller_stash) {
        GV *alias = *(GV **)hv_fetch(caller_stash,
                                     (char *)name, name_len, TRUE);

        if (!isGV(alias)) {
            gv_init(alias, caller_stash, name, name_len, TRUE);
        }

#ifdef MUTABLE_CV
        GvCV_set(alias, MUTABLE_CV(SvREFCNT_inc(GvCV(*gvp))));
#else
        GvCV_set(alias, (CV*)(SvREFCNT_inc(GvCV(*gvp))));
#endif
    }
}

int modperl_const_compile(pTHX_ const char *classname,
                          const char *arg,
                          const char *name)
{
    HV *stash = gv_stashpv(classname, TRUE);
    HV *caller_stash = (HV *)NULL;
    constants_lookup lookup;
    constants_group_lookup group_lookup;

    if (strnEQ(classname, "APR", 3)) {
        lookup       = modperl_constants_lookup_apr_const;
        group_lookup = modperl_constants_group_lookup_apr_const;
    }
    else if (strnEQ(classname, "Apache2", 7)) {
        lookup       = modperl_constants_lookup_apache2_const;
        group_lookup = modperl_constants_group_lookup_apache2_const;
    }
    else {
        lookup       = modperl_constants_lookup_modperl;
        group_lookup = modperl_constants_group_lookup_modperl;
    }

    if (*arg != '-') {
        /* only export into callers namespace without -compile arg */
        caller_stash = gv_stashpv(arg, TRUE);
    }

    if (*name == ':') {
        int i;
        const char **group;

        name++;

        group = (*group_lookup)(name);

        for (i=0; group[i]; i++) {
            new_constsub(aTHX_ lookup, caller_stash, stash, group[i]);
        }
    }
    else {
        if (*name == '&') {
            name++;
        }
        new_constsub(aTHX_ lookup, caller_stash, stash, name);
    }

    return 1;
}

XS(XS_modperl_const_compile)
{
    I32 i;
    STRLEN n_a;
    char *stashname = HvNAME(GvSTASH(CvGV(cv)));
    const char *classname, *arg;
    dXSARGS;

    if (items < 2) {
        Perl_croak(aTHX_ "Usage: %s->compile(...)", stashname);
    }

    classname = *(stashname + 1) == 'P'
        ? "APR::Const"
        : (*stashname == 'A' ? "Apache2::Const" : "ModPerl");
    arg = SvPV(ST(1),n_a);

    for (i=2; i<items; i++) {
        (void)modperl_const_compile(aTHX_ classname, arg, SvPV(ST(i), n_a));
    }

    XSRETURN_EMPTY;
}
