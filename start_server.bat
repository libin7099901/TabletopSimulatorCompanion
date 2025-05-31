@echo off
rem TabletopSimulatorCompanion (TTS Companion) - 服务端启动批处理文件

echo ================================================
echo TTS Companion 服务端启动工具 - Windows 批处理版本
echo ================================================
echo.

rem 检查Python是否安装
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: 未安装Python或未添加到PATH
    echo 请安装Python 3.9+并确保添加到PATH环境变量
    pause
    exit /b
)

rem 检查是否有正在运行的TTS Companion服务
echo 注意: 如果已有TTS Companion服务正在运行，将会自动关闭并重启服务
echo 如不希望重启服务，请在5秒内按Ctrl+C取消...
timeout /t 5 >nul

rem 启动服务器
python start_server.py
pause 