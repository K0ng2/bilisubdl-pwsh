$API_URL = "https://api.bilibili.tv/intl/gateway/web/v2"
$info_ep = $API_URL + "/ogv/play/{0}?season_id={1}&platform=web"
$API_episode = $API_URL + "/subtitle?&episode_id="
function Get-Bilibili {
  param(
    [string[]]$id,
    [Alias('l')][string]$lang,
    [Alias('w')][switch]$overwrite,
    [switch]$list
  )

  foreach ($s in $id) {
    $info = Invoke-RestMethod -Method Get -Uri ($info_ep -f 'season_info', $s)
    $epList = Invoke-RestMethod -Method Get -Uri ($info_ep -f 'episodes', $s)
    $genres = @()
    foreach ($genre in $info.data.season.styles) {$genres+=$genre.title}
    [PSCustomObject]@{
      Title = $info.data.season.title
      Genres = $genres -join ', '
      TotalEpisode = $info.data.season.total_episodes_text
    } | Format-List
    $title = New-CleanText $info.data.season.title
    $null = New-Item -Name $title -ItemType "directory" -Force
    foreach ($section in $epList.data.sections) {
      Write-Host $ep.ep_list_title
      foreach ($ep in $section.episodes) {
        $ep_name = New-CleanText $ep.title_display
        $filename = $title + '\' + ("{0}.{1}.srt" -f $ep_name, $lang)
        if ((Test-Path $filename) -and !($overwrite)) {
          Write-Warning "$filename : Already exists"
          continue
        }
        $episode_url = "{0}{1}" -f $API_episode, $ep.episode_id
        $episode = Invoke-RestMethod -Method Get -Uri $episode_url
        foreach ($j in $episode.data.subtitles) {
          if ($lang -eq $j.lang_key) {
            $sub = Invoke-RestMethod -Method Get -Uri $j.url
            New-SRT $sub.body | Out-File $filename
            Write-Host "Writing subtitle: $filename"
          }
        }
      }
    }
  }
}

function New-SRT {
  param(
    $body
  )

  $sub = ''
  for ($i = 0; $i -lt ($body).Length; $i++) {
    if (($i -ne 0) -or $i -eq ($body).Length) {
      $sub += "`n`n"
    }
    $content = $body[$i].content
    if ($body[$i].location -eq 2) {
      $line = $content
    } else {
      $location = $body[$i].location
      $line = "{{\an$location}}$content"
    }
    $timeFrom = "{0:hh\:mm\:ss\,fff}" -f ([timespan]::fromseconds($body[$i].from))
    $timeTo = "{0:hh\:mm\:ss\,fff}" -f ([timespan]::fromseconds($body[$i].to))
    $sub += "{0}`n$timeFrom --> $timeTo`n$line" -f ($i + 1)
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
