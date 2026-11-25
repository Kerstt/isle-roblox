@echo off
rem Saves your changes to GitHub: double-click, type what you changed, press Enter.
setlocal EnableDelayedExpansion
cd /d "%~dp0"
git add -A
git diff --cached --quiet
if %errorlevel%==0 (
  echo Nothing new to push.
  pause
  exit /b 0
)
echo Changed files:
git status --short
echo.
set "MSG="
set /p "MSG=What did you change? (leave empty to cancel) "
if not defined MSG (
  git reset -q
  echo Cancelled. Nothing was committed.
  pause
  exit /b 0
)
git commit -q -m "!MSG!" || goto :failed
git pull --rebase -q || goto :conflict
git push -q || goto :failed
echo.
echo Pushed to GitHub!
pause
exit /b 0

:conflict
git rebase --abort >nul 2>&1
echo.
echo GitHub has changes that clash with yours. Your commit is saved locally and
echo nothing was lost, but it was not pushed. Ask Claude to merge it for you.
pause
exit /b 1

:failed
echo.
echo Something went wrong (see the message above). Nothing was lost; ask for help.
pause
exit /b 1
