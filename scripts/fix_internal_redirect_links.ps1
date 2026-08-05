$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$map = [ordered]@{
  'href="/laco/lubri_joint"' = 'href="/laco/lubri_joint/"'
  'href="/tempil"' = 'href="/tempil/"'
  'href="/markal/paint_riter_heat_treat"' = 'href="/markal/paint_riter_heat_treat/"'
  'href="/markal/holder_100"' = 'href="/markal/holder_100/"'
  'href="/markal/heat_stik"' = 'href="/markal/heat_stik/"'
  'href="/laco/regular_flux_paste"' = 'href="/laco/regular_flux_paste/"'
  'href="/markal/paintstik_high_intensity"' = 'href="/markal/paintstik_high_intensity/"'
  'href="/markal/quik_stik_all_purpose_mini"' = 'href="/markal/quik_stik_all_purpose_mini/"'
  'href="/markal/stylmark_low_corrosion"' = 'href="/markal/stylmark_low_corrosion/"'
  'href="/laco/ez_break_copper_and_nickel_grade"' = 'href="/laco/ez_break_copper_and_nickel_grade/"'
  'href="/markal/china_marker"' = 'href="/markal/china_marker/"'
  'href="/laco/anti_heat"' = 'href="/laco/anti_heat/"'
  'href="/laco/bloc_it"' = 'href="/laco/bloc_it/"'
  'href="/laco/epoxy_stik"' = 'href="/laco/epoxy_stik/"'
  'href="/markal/trades_marker_water_soluble"' = 'href="/markal/trades_marker_water_soluble/"'
  'href="/laco/cool_gel"' = 'href="/laco/cool_gel/"'
  'href="/markal/paintstik_water_removable_fine"' = 'href="/markal/paintstik_water_removable_fine/"'
}

$files = Get-ChildItem -Recurse -File -Include *.html,*.xml
$updated = 0

foreach ($file in $files) {
  $content = Get-Content -Raw -LiteralPath $file.FullName
  $original = $content

  foreach ($entry in $map.GetEnumerator()) {
    $content = $content.Replace($entry.Key, $entry.Value)
  }

  if ($content -ne $original) {
    Set-Content -LiteralPath $file.FullName -Value $content -Encoding UTF8
    $updated++
  }
}

Write-Output ("updated_files=" + $updated)
