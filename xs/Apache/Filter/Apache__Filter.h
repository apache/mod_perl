#define mpxs_Apache__RequestRec_add_output_filter(r, name, ctx) \
ap_add_output_filter(name, ctx, r, NULL)
