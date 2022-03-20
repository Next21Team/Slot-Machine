$modelname "slot_machine.mdl"
$cd ".\"
$cdtexture "textures"
$cliptotextures

$flags 512


$bbox 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000
$cbox 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000
$eyeposition 0.000000 0.000000 0.000000

$hbox 0 "root" -16.870000 0.000000 -10.040000 16.870000 74.930000 19.280000

$scale 32.0

$body "ref" "bodies/ref"
$body "reels" "bodies/reels"

$bodygroup "row"
{
blank
studio "bodies/row_1"
studio "bodies/row_2"
studio "bodies/row_3"
studio "bodies/row_d"
studio "bodies/row_d_alt"
}

$texrendermode "row.bmp" "additive" 

$controller 0 "reel1" XR 0.000000 179.296875
$controller 1 "reel2" XR 0.000000 179.296875
$controller 2 "reel3" XR 0.000000 179.296875

$sequence "idle" "bodies/ref" fps 1
$sequence "roll" "anims/roll" fps 15
