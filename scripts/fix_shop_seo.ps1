$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-DuplicateShopMaps {
  $dirs = Get-ChildItem .\shop -Directory | Select-Object -ExpandProperty Name
  $groups = @{}

  foreach ($dir in $dirs) {
    if ($dir -match "(.+)-(\d{5,6})$") {
      $base = $matches[1]
      $normalizedPn = $matches[2].PadLeft(6, "0")
      $key = "$base|$normalizedPn"

      if (-not $groups.ContainsKey($key)) {
        $groups[$key] = @()
      }

      $groups[$key] += $dir
    }
  }

  $pathMap = @{}
  $pnMap = @{}

  foreach ($entry in $groups.GetEnumerator()) {
    $names = @($entry.Value)
    if ($names.Count -le 1) {
      continue
    }

    $preferred = $names | Where-Object { $_ -match "-\d{6}$" } | Sort-Object | Select-Object -First 1
    if (-not $preferred) {
      $preferred = $names | Sort-Object | Select-Object -First 1
    }

    if ($preferred -notmatch "-(\d{6})$") {
      continue
    }

    $preferredPn = $matches[1]

    foreach ($name in $names) {
      if ($name -eq $preferred) {
        continue
      }

      if ($name -match "-(\d{5,6})$") {
        $oldPn = $matches[1]
        $pathMap["/shop/$name/"] = "/shop/$preferred/"
        $pnMap[$oldPn] = $preferredPn
      }
    }
  }

  return @{
    PathMap = $pathMap
    PnMap = $pnMap
  }
}

function Replace-PathMap([string]$value, [hashtable]$pathMap) {
  if ([string]::IsNullOrEmpty($value)) {
    return $value
  }

  foreach ($entry in $pathMap.GetEnumerator()) {
    $value = $value.Replace($entry.Key, $entry.Value)
  }

  return $value
}

function Update-CatalogData([hashtable]$pathMap, [hashtable]$pnMap) {
  $catalogPath = Join-Path $root "shop\catalog-index.json"
  $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json

  foreach ($group in $catalog) {
    foreach ($item in $group.items) {
      $oldPn = [string]$item.pn

      if ($item.PSObject.Properties.Name -contains "url") {
        $item.url = Replace-PathMap $item.url $pathMap
      }

      if ($item.PSObject.Properties.Name -contains "img") {
        $item.img = Replace-PathMap $item.img $pathMap
      }

      if ($pnMap.ContainsKey($oldPn)) {
        $newPn = $pnMap[$oldPn]
        $item.pn = $newPn

        if ($item.PSObject.Properties.Name -contains "s" -and $item.s) {
          $searchTokens = @($item.s)
          if ($item.s -notmatch [regex]::Escape($newPn)) {
            $searchTokens += $newPn
          }
          if ($item.s -notmatch [regex]::Escape($oldPn)) {
            $searchTokens += $oldPn
          }
          $item.s = ($searchTokens -join " ").Trim()
        }
      }
    }
  }

  $catalog | ConvertTo-Json -Depth 8 -Compress | Set-Content -LiteralPath $catalogPath -Encoding UTF8
}

function Update-SearchIndex([hashtable]$pathMap, [hashtable]$pnMap) {
  $searchPath = Join-Path $root "shop\search-index.json"
  $searchIndex = Get-Content -Raw -LiteralPath $searchPath | ConvertFrom-Json

  foreach ($item in $searchIndex) {
    $oldPn = [string]$item.pn
    $item.url = Replace-PathMap $item.url $pathMap

    if ($pnMap.ContainsKey($oldPn)) {
      $item.pn = $pnMap[$oldPn]
    }
  }

  $searchIndex | ConvertTo-Json -Depth 5 -Compress | Set-Content -LiteralPath $searchPath -Encoding UTF8
}

function Update-PnIndex([hashtable]$pathMap, [hashtable]$pnMap) {
  $pnIndexPath = Join-Path $root "shop\pn-index.json"
  $pnIndexObject = Get-Content -Raw -LiteralPath $pnIndexPath | ConvertFrom-Json
  $pnEntries = @{}

  foreach ($prop in $pnIndexObject.PSObject.Properties) {
    $pnEntries[$prop.Name] = Replace-PathMap ([string]$prop.Value) $pathMap
  }

  foreach ($entry in $pnMap.GetEnumerator()) {
    $oldPn = $entry.Key
    $newPn = $entry.Value
    $preferredDir = $pathMap["/shop/$((Get-ChildItem .\shop -Directory | Where-Object { $_.Name -match "-$oldPn$" } | Select-Object -First 1).Name)/"]

    if ($preferredDir) {
      $pnEntries[$oldPn] = $preferredDir
      $pnEntries[$newPn] = $preferredDir
    }
  }

  $ordered = [ordered]@{}
  foreach ($key in ($pnEntries.Keys | Sort-Object)) {
    $ordered[$key] = $pnEntries[$key]
  }

  $ordered | ConvertTo-Json | Set-Content -LiteralPath $pnIndexPath -Encoding UTF8
}

function Update-ShopIndexHtml([hashtable]$pathMap, [hashtable]$pnMap) {
  $indexPath = Join-Path $root "shop\index.html"
  $content = Get-Content -Raw -LiteralPath $indexPath

  foreach ($entry in $pathMap.GetEnumerator()) {
    $content = $content.Replace($entry.Key, $entry.Value)
  }

  foreach ($entry in $pnMap.GetEnumerator()) {
    $oldPn = $entry.Key
    $newPn = $entry.Value
    $content = $content.Replace("data-pn=`"$oldPn`"", "data-pn=`"$newPn`"")
    $content = $content.Replace(">Mã $oldPn<", ">Mã $newPn<")
  }

  Set-Content -LiteralPath $indexPath -Value $content -Encoding UTF8
}

function ConvertTo-CanonicalJson([string]$jsonText) {
  $json = $jsonText | ConvertFrom-Json
  $json.PSObject.Properties.Remove("offers")
  return ($json | ConvertTo-Json -Depth 50 -Compress)
}

function Update-ProductPages {
  $shopFiles = Get-ChildItem .\shop -Recurse -Filter index.html | Where-Object {
    $_.FullName -notmatch "\\shop\\index\.html$"
  }

  foreach ($file in $shopFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName

    if ($content -match '<meta name="robots" content="noindex, follow">' -and $content -match '<meta http-equiv="refresh"') {
      continue
    }

    if ($file.Directory.Name -notmatch "-(\d{5,6})$") {
      continue
    }

    $pn = $matches[1]

    $productScript = [regex]::Match(
      $content,
      '<script type="application/ld\+json">(\{.*?"@type"\s*:\s*"Product".*?\})</script>',
      [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if ($productScript.Success) {
      $canonicalJson = ConvertTo-CanonicalJson $productScript.Groups[1].Value
      $replacement = '<script type="application/ld+json">' + $canonicalJson + '</script>'
      $content = $content.Remove($productScript.Index, $productScript.Length).Insert($productScript.Index, $replacement)
    }

    $content = [regex]::Replace(
      $content,
      'chốt đơn cho mã\s+\d{5,6}',
      "chốt đơn cho mã $pn"
    )

    if ($content -match '<h2 class="p-h1">([^<]+)</h2>') {
      $h2 = $matches[1]
    } else {
      $h2 = ""
    }

    if ($content -match '<p class="p-vi">([^<]+)</p>') {
      $pvi = $matches[1]
    } else {
      $pvi = ""
    }

    $rangeText = $null
    if ($h2 -match '(\d+°F~\d+°F)') {
      $rangeText = $matches[1]
    }

    if ($rangeText) {
      $content = [regex]::Replace(
        $content,
        '(<div class="spec-card"><div class="spec-card__val">)([^<]+)(</div><div class="spec-card__lbl">Nhiệt độ/điều kiện</div></div>)',
        {
          param($match)
          $match.Groups[1].Value + $rangeText + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '<div class="spec-card">\$\d[^<]*</div><div class="spec-card__lbl">Nhiệt độ/điều kiện</div></div>',
        {
          param($match)
          '<div class="spec-card"><div class="spec-card__val">' + $rangeText + '</div><div class="spec-card__lbl">Nhiệt độ/điều kiện</div></div>'
        }
      )

      $content = [regex]::Replace(
        $content,
        '(<details class="faq-item"><summary>Dải nhiệt độ / điều kiện làm việc là bao nhiêu\?</summary><p>)([^<]+)(</p></details>)',
        {
          param($match)
          $match.Groups[1].Value + $rangeText + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '(</details>)\$\d[^<]*</p></details>(<details class="faq-item"><summary>Cần lưu ý gì khi đặt mua mã \d{5,6}\?</summary>)',
        {
          param($match)
          $match.Groups[1].Value + '<details class="faq-item"><summary>Dải nhiệt độ / điều kiện làm việc là bao nhiêu?</summary><p>' + $rangeText + '</p></details>' + $match.Groups[2].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '("name"\s*:\s*"Dải nhiệt độ / điều kiện làm việc là bao nhiêu\?"\s*,\s*"acceptedAnswer"\s*:\s*\{"@type"\s*:\s*"Answer"\s*,\s*"text"\s*:\s*")([^"]+)("\}\})',
        {
          param($match)
          $match.Groups[1].Value + $rangeText + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '(\{"@type": "Question", "name": "Mã \d{5,6} dùng được trên bề mặt nào\?", "acceptedAnswer": \{"@type": "Answer", "text": ".*?"\}\}, )\{"@type": "Question", \$.*?"\}\}, (\{"@type": "Question", "name": "Cần lưu ý gì khi đặt mua mã \d{5,6}\?")',
        {
          param($match)
          $match.Groups[1].Value + '{"@type": "Question", "name": "Dải nhiệt độ / điều kiện làm việc là bao nhiêu?", "acceptedAnswer": {"@type": "Answer", "text": "' + $rangeText + '"}}, ' + $match.Groups[2].Value
        },
        [System.Text.RegularExpressions.RegexOptions]::Singleline
      )

      $content = [regex]::Replace(
        $content,
        '("name"\s*:\s*"Nhiệt độ/điều kiện"\s*,\s*"value"\s*:\s*")([^"]+)(")',
        {
          param($match)
          $match.Groups[1].Value + $rangeText + $match.Groups[3].Value
        }
      )
    }

    if ($content -match 'Markal Heat Stik® 200F-1000F') {
      $metaDescription = "$h2 - $pvi, mã $pn chính hãng Markal. Dùng để đánh dấu bề mặt nóng trong nhà máy thép, cơ khí và kết cấu kim loại."
      $bodyDescription = "$h2 (Part Number $pn) là bút đánh dấu chịu nhiệt Markal dùng cho bề mặt nóng trong nhà máy thép, xưởng cơ khí và các ứng dụng kết cấu kim loại. Fast Group Engineering hỗ trợ báo giá, SDS/MSDS và tư vấn chọn đúng dải nhiệt theo điều kiện sử dụng."

      $content = [regex]::Replace(
        $content,
        '(<meta name="description" content=")([^"]+)(">)',
        {
          param($match)
          $match.Groups[1].Value + $metaDescription + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '(<meta property="og:description" content=")([^"]+)(">)',
        {
          param($match)
          $match.Groups[1].Value + $metaDescription + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '("description"\s*:\s*")([^"]+)(")',
        {
          param($match)
          $match.Groups[1].Value + $metaDescription + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '(<p class="section__desc_content">)(.*?)(</p>)',
        {
          param($match)
          $match.Groups[1].Value + $bodyDescription + $match.Groups[3].Value
        },
        [System.Text.RegularExpressions.RegexOptions]::Singleline
      )
    }

    $faqMatches = [regex]::Matches(
      $content,
      '<details class="faq-item"(?: open)?><summary>(.*?)</summary><p>(.*?)</p></details>',
      [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if ($faqMatches.Count -gt 0) {
      $faqEntities = @()

      foreach ($faqMatch in $faqMatches) {
        $question = [System.Net.WebUtility]::HtmlDecode(($faqMatch.Groups[1].Value -replace '\s+', ' ').Trim())
        $answer = [System.Net.WebUtility]::HtmlDecode(($faqMatch.Groups[2].Value -replace '\s+', ' ').Trim())

        $faqEntities += [ordered]@{
          '@type' = 'Question'
          name = $question
          acceptedAnswer = [ordered]@{
            '@type' = 'Answer'
            text = $answer
          }
        }
      }

      $faqJson = [ordered]@{
        '@context' = 'https://schema.org/'
        '@type' = 'FAQPage'
        mainEntity = $faqEntities
      } | ConvertTo-Json -Depth 20 -Compress

      $content = [regex]::Replace(
        $content,
        '<script type="application/ld\+json">\{[^<]*?"@type"\s*:\s*"FAQPage"[^<]*?\}</script>',
        '<script type="application/ld+json">' + $faqJson + '</script>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
      )
    }

    if ($content -match '<meta name="description" content="([^"]+)">') {
      $currentMetaDescription = [System.Net.WebUtility]::HtmlDecode($matches[1])
    } else {
      $currentMetaDescription = ""
    }

    if ($currentMetaDescription -match '^Markal Heat Stik® 200F-1000F') {
      $currentMetaDescription = "$h2 - $pvi, mã $pn chính hãng Markal. Dùng để đánh dấu bề mặt nóng trong nhà máy thép, cơ khí và kết cấu kim loại."
      $bodyDescription = "$h2 (Part Number $pn) là bút đánh dấu chịu nhiệt Markal dùng cho bề mặt nóng trong nhà máy thép, xưởng cơ khí và các ứng dụng kết cấu kim loại. Fast Group Engineering hỗ trợ báo giá, SDS/MSDS và tư vấn chọn đúng dải nhiệt theo điều kiện sử dụng."

      $content = [regex]::Replace(
        $content,
        '(<meta name="description" content=")([^"]+)(">)',
        {
          param($match)
          $match.Groups[1].Value + $currentMetaDescription + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '(<meta property="og:description" content=")([^"]+)(">)',
        {
          param($match)
          $match.Groups[1].Value + $currentMetaDescription + $match.Groups[3].Value
        }
      )

      $content = [regex]::Replace(
        $content,
        '(<p class="section__desc_content">)(.*?)(</p>)',
        {
          param($match)
          $match.Groups[1].Value + $bodyDescription + $match.Groups[3].Value
        },
        [System.Text.RegularExpressions.RegexOptions]::Singleline
      )
    }

    if ($content -match '<link rel="canonical" href="([^"]+)">') {
      $canonicalUrl = $matches[1]
    } else {
      $canonicalUrl = "https://markal.com.vn/shop/$($file.Directory.Name)/"
    }

    if ($content -match '<meta property="og:image" content="([^"]+)">') {
      $primaryImage = $matches[1]
    } elseif ($content -match '<img id="mainImg" src="([^"]+)"') {
      $imageSrc = $matches[1]
      if ($imageSrc -match '^https?://') {
        $primaryImage = $imageSrc
      } elseif ($imageSrc.StartsWith('/')) {
        $primaryImage = "https://markal.com.vn$imageSrc"
      } else {
        $primaryImage = ($canonicalUrl.TrimEnd('/') + '/' + $imageSrc.TrimStart('./'))
      }
    } else {
      $primaryImage = ""
    }

    if ($content -match '<p class="p-sub">([^<]+?)\s+·') {
      $brandName = [System.Net.WebUtility]::HtmlDecode($matches[1].Trim())
    } else {
      $brandName = "Markal"
    }

    $productName = if ($pvi) {
      "$h2 - $pvi ($brandName $pn)"
    } else {
      "$h2 ($brandName $pn)"
    }

    $specMatches = [regex]::Matches(
      $content,
      '<div class="spec-card"><div class="spec-card__val">(.*?)</div><div class="spec-card__lbl">(.*?)</div></div>',
      [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    $additionalProperties = @()
    foreach ($specMatch in $specMatches) {
      $specValue = [System.Net.WebUtility]::HtmlDecode(($specMatch.Groups[1].Value -replace '\s+', ' ').Trim())
      $specLabel = [System.Net.WebUtility]::HtmlDecode(($specMatch.Groups[2].Value -replace '\s+', ' ').Trim())

      if ($specValue -and $specLabel) {
        $additionalProperties += [ordered]@{
          '@type' = 'PropertyValue'
          name = $specLabel
          value = $specValue
        }
      }
    }

    $productJson = [ordered]@{
      '@context' = 'https://schema.org/'
      '@type' = 'Product'
      name = $productName
      image = @($primaryImage)
      description = $currentMetaDescription
      sku = $pn
      mpn = $pn
      brand = [ordered]@{
        '@type' = 'Brand'
        name = $brandName
      }
      manufacturer = [ordered]@{
        '@type' = 'Organization'
        name = 'LACO INDUSTRIES LLC'
        address = [ordered]@{
          '@type' = 'PostalAddress'
          addressCountry = 'US'
        }
      }
      additionalProperty = $additionalProperties
    } | ConvertTo-Json -Depth 20 -Compress

    $breadcrumbJson = [ordered]@{
      '@context' = 'https://schema.org/'
      '@type' = 'BreadcrumbList'
      itemListElement = @(
        [ordered]@{
          '@type' = 'ListItem'
          position = 1
          name = 'Trang chủ'
          item = 'https://markal.com.vn/'
        },
        [ordered]@{
          '@type' = 'ListItem'
          position = 2
          name = 'Shop'
          item = 'https://markal.com.vn/shop/'
        },
        [ordered]@{
          '@type' = 'ListItem'
          position = 3
          name = $h2
          item = $canonicalUrl
        }
      )
    } | ConvertTo-Json -Depth 20 -Compress

    $jsonLdBlock = @(
      '<script type="application/ld+json">' + $productJson + '</script>'
      '<script type="application/ld+json">' + $breadcrumbJson + '</script>'
      '<script type="application/ld+json">' + $faqJson + '</script>'
    ) -join "`r`n"

    $styleIndex = $content.IndexOf('<style>')
    if ($styleIndex -ge 0) {
      $headPrefix = $content.Substring(0, $styleIndex)
      $rest = $content.Substring($styleIndex)
      $cleanHeadPrefix = [regex]::Replace(
        $headPrefix,
        '<script type="application/ld\+json">\{[^<]*?</script>\s*',
        '',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
      )
      $content = $cleanHeadPrefix.TrimEnd() + "`r`n  " + $jsonLdBlock + "`r`n  " + $rest
    } else {
      $content = $content.Replace('<style>', $jsonLdBlock + "`r`n  <style>")
    }

    Set-Content -LiteralPath $file.FullName -Value $content -Encoding UTF8
  }
}

function Update-Sitemap([hashtable]$pathMap) {
  $sitemapPath = Join-Path $root "sitemap.xml"
  [xml]$xml = Get-Content -Raw -LiteralPath $sitemapPath

  $entries = foreach ($url in $xml.urlset.url) {
    [pscustomobject]@{
      loc = [string]$url.loc
      lastmod = [string]$url.lastmod
      changefreq = [string]$url.changefreq
      priority = [string]$url.priority
    }
  }

  $nonPreferredFullUrls = @{}
  foreach ($entry in $pathMap.GetEnumerator()) {
    $nonPreferredFullUrls["https://markal.com.vn$($entry.Key)"] = $true
  }

  $today = Get-Date -Format "yyyy-MM-dd"

  $filtered = foreach ($entry in $entries) {
    if ($nonPreferredFullUrls.ContainsKey($entry.loc)) {
      continue
    }

    if ($entry.loc -eq "https://markal.com.vn/shop/" -or $entry.loc -like "https://markal.com.vn/shop/*") {
      $entry.lastmod = $today
    }

    $entry
  }

  $lines = @(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'
    '        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    '        xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9'
    '        http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">'
    ''
  )

  foreach ($entry in $filtered) {
    $lines += '  <url>'
    $lines += "    <loc>$($entry.loc)</loc>"
    if ($entry.lastmod) {
      $lines += "    <lastmod>$($entry.lastmod)</lastmod>"
    }
    if ($entry.changefreq) {
      $lines += "    <changefreq>$($entry.changefreq)</changefreq>"
    }
    if ($entry.priority) {
      $lines += "    <priority>$($entry.priority)</priority>"
    }
    $lines += '  </url>'
  }

  $lines += '</urlset>'
  Set-Content -LiteralPath $sitemapPath -Value $lines -Encoding UTF8
}

$maps = Get-DuplicateShopMaps

Update-CatalogData -pathMap $maps.PathMap -pnMap $maps.PnMap
Update-SearchIndex -pathMap $maps.PathMap -pnMap $maps.PnMap
Update-PnIndex -pathMap $maps.PathMap -pnMap $maps.PnMap
Update-ShopIndexHtml -pathMap $maps.PathMap -pnMap $maps.PnMap
Update-ProductPages
Update-Sitemap -pathMap $maps.PathMap

Write-Output ("normalized_paths=" + $maps.PathMap.Count)
Write-Output ("normalized_pns=" + $maps.PnMap.Count)
