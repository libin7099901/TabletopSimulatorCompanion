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

rem 启动服务器
python start_server.py
pause 