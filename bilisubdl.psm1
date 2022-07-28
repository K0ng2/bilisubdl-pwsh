$API_URL = "https://api.bilibili.tv/intl/gateway/web/v2"
$INFO_EP_URL = $API_URL + "/ogv/play/{0}?season_id={1}"
# $EP_URL = $API_URL + "/subtitle?s_locale&episode_id="
$EP_URL = $API_URL + "/m/subtitle?ep_id="
function Get-Bilibili {
  param(
    [string[]]$id,
    [Alias('l')][string]$lang,
    [Alias('w')][switch]$overwrite,
    [switch]$list
  )

  foreach ($s in $id) {
    $info = Invoke-RestMethod -Method Get -Uri ($INFO_EP_URL -f 'season_info', $s)
    # $genres = @()
    # foreach ($genre in $info.data.season.styles) { $genres += $genre.title }
    # [PSCustomObject]@{
    #   Title        = $info.data.season.title
    #   Genres       = $genres -join ', '
    #   TotalEpisode = $info.data.season.total_episodes_text
    # } | Format-List
    $epList = Invoke-RestMethod -Method Get -Uri ($INFO_EP_URL -f 'episodes', $s)
    $title = New-CleanText $info.data.season.title
    $null = New-Item -Name $title -ItemType "directory" -Force
    foreach ($section in $epList.data.sections) {
      Write-Host $ep.ep_list_title
      foreach ($ep in $section.episodes) {
        $name = New-CleanText $ep.title_display
        # if ($ep.title_display) {
          # $ep_name = New-CleanText $ep.title_display
          # $name = "$name - $ep_name"
        # }
        $filename = Join-Path $title "$name.$lang.srt"
        if ((Test-Path $filename) -and !($overwrite)) {
          Write-Host "# $filename"
          continue
        }
        if ()
        $rawSub = Get-BilibiliEpisode $ep.episode_id $lang
        New-SRT $rawSub.body | Out-File $filename
        Write-Host "* $filename"
      }
    }
  }
}

function Get-BilibiliEpisode {
  param(
    [string]$id,
    [string]$lang
  )
  $episode = Invoke-RestMethod -Method Get -Uri "$EP_URL$id"
  foreach ($j in $episode.data.subtitles) {
    if ($lang -eq $j.key) {
      if ($j.is_machine) {
        Write-Warning 'Machine translation'
      }
      return Invoke-RestMethod -Method Get -Uri $j.url
    }
  }
  return $null
}

function New-SRT {
  param(
    $body
  )

  $sub = ''
  for ($i = 0; $i -lt ($body).Length; $i++) {
    if (($i -ne 0) -or ($i -eq ($body).Length)) {
      $sub += "`n`n"
    }
    $content = $body[$i].content
    $location = $body[$i].location
    if ($location -ne 2) {
      $content = "{{\an$location}}$content"
    }
    $timeFrom = "{0:hh\:mm\:ss\,fff}" -f ([timespan]::fromseconds($body[$i].from))
    $timeTo = "{0:hh\:mm\:ss\,fff}" -f ([timespan]::fromseconds($body[$i].to))
    $sub += "{0}`n$timeFrom --> $timeTo`n$content" -f ($i + 1)
  }
  return $sub
}

function New-CleanText {
  param(
    [string]$t
  )
  $t = $t -replace '[*|:<>?/\|"]', '_' `
    -replace "`n", ' '
  return $t.TrimEnd('.')
}

Export-ModuleMember -Function Get-Bilibili
