$fileExtensions = @('*.cs', '*.md', '.js', '.ts', '.vue')
$outputFile = "all_files_content.txt"
$files = Get-ChildItem -Path "." -Include $fileExtensions -Recurse -File

"" | Out-File $outputFile -Encoding UTF8

foreach ($file in $files) {
    Write-Host "Чтение: $($file.Name)"
    
    try {
        # Просто читаем и добавляем содержимое
        "// ФАЙЛ: $($file.FullName)" | Out-File $outputFile -Encoding UTF8 -Append
        
        if ($file.Extension -eq '.md') {
            Get-Content $file.FullName -Encoding Default | Out-File $outputFile -Encoding UTF8 -Append
        } else {
            Get-Content $file.FullName -Encoding UTF8 | Out-File $outputFile -Encoding UTF8 -Append
        }
        
        "`r`n" | Out-File $outputFile -Encoding UTF8 -Append
        Write-Host "  OK" -ForegroundColor Green
    }
    catch {
        "// ОШИБКА: $($file.FullName)" | Out-File $outputFile -Encoding UTF8 -Append
        Write-Host "  Ошибка" -ForegroundColor Red
    }
}

Write-Host "Завершено! Файл: $outputFile" -ForegroundColor Green