(* PASTA/84 Dos unit declarations *)
{$l dos_p.ir4}

function GetEnv(Name: String): String; external 'pas_getenv';
function FExpand(Path: String): String; external 'pas_fexpand';
