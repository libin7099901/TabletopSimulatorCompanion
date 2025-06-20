#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - 服务端启动脚本
"""

import os
import sys
import subprocess
import signal
import time
import re
from pathlib import Path

def find_python_executable():
    """查找Python可执行文件"""
    # 尝试使用虚拟环境中的Python
    venv_python = None
    if os.path.exists('venv'):
        if sys.platform == 'win32':
            venv_python = os.path.join('venv', 'Scripts', 'python.exe')
        else:
            venv_python = os.path.join('venv', 'bin', 'python')
        
        if os.path.exists(venv_python):
            return venv_python
    
    # 默认使用系统Python
    return sys.executable

def check_requirements():
    """检查依赖是否已安装"""
    print("检查依赖项...")
    python_exec = find_python_executable()
    requirements_path = os.path.join('TTSAssistantServer', 'requirements.txt')
    
    if not os.path.exists(requirements_path):
        print(f"错误: 找不到依赖文件 {requirements_path}")
        return False
    
    try:
        subprocess.run([python_exec, '-c', 'import flask, langchain'], 
                      check=True, capture_output=True)
        print("基本依赖已安装")
        return True
    except subprocess.CalledProcessError:
        print("未安装必要依赖，请运行以下命令:")
        print(f"{python_exec} -m pip install -r {requirements_path}")
        
        user_input = input("是否现在安装依赖? (y/n): ").lower()
        if user_input == 'y':
            try:
                subprocess.run([python_exec, '-m', 'pip', 'install', '-r', requirements_path], 
                              check=True)
                print("依赖安装完成")
                return True
            except subprocess.CalledProcessError as e:
                print(f"依赖安装失败: {e}")
                return False
        else:
            return False

def check_and_kill_existing_server():
    """检查并关闭已存在的服务进程"""
    print("检查是否有已运行的 TTS Companion 服务...")
    server_path = os.path.join('TTSAssistantServer', 'app.py').replace('\\', '\\\\')
    killed = False
    
    if sys.platform == 'win32':
        # Windows 使用 tasklist 和 findstr 命令
        try:
            # 获取所有Python进程
            output = subprocess.check_output('tasklist /FI "IMAGENAME eq python.exe" /V /FO CSV', 
                                            shell=True, text=True)
            # 在输出中查找运行app.py的进程
            for line in output.splitlines():
                if 'app.py' in line:
                    # 从CSV格式输出中提取PID
                    match = re.search(r'"python\.exe","(\d+)"', line)
                    if match:
                        pid = match.group(1)
                        print(f"发现运行中的TTS Companion服务 (PID: {pid})，正在关闭...")
                        subprocess.run(f'taskkill /F /T /PID {pid}', shell=True, 
                                      capture_output=True)
                        killed = True
                        # 等待进程完全终止
                        time.sleep(1)
        except subprocess.CalledProcessError:
            print("检查运行中的服务时出错")
    else:
        # Linux/Mac 使用 ps 和 grep 命令
        try:
            # 获取所有包含app.py的Python进程
            cmd = f"ps -ef | grep '[p]ython.*{server_path}' | awk '{{print $2}}'"
            output = subprocess.check_output(cmd, shell=True, text=True)
            
            # 如果找到进程，关闭它
            if output.strip():
                for pid in output.splitlines():
                    if pid.strip():
                        pid = pid.strip()
                        print(f"发现运行中的TTS Companion服务 (PID: {pid})，正在关闭...")
                        os.kill(int(pid), signal.SIGTERM)
                        killed = True
                        # 等待进程完全终止
                        time.sleep(1)
        except subprocess.CalledProcessError:
            print("检查运行中的服务时出错")
    
    if killed:
        print("已关闭之前运行的TTS Companion服务")
    else:
        print("未发现正在运行的TTS Companion服务")
    
    return killed

def start_server():
    """启动服务器"""
    print("启动 TTS Companion 服务器...")
    
    # 获取服务器脚本路径
    server_path = os.path.join('TTSAssistantServer', 'app.py')
    if not os.path.exists(server_path):
        print(f"错误: 找不到服务器脚本 {server_path}")
        return None
    
    # 使用找到的Python解释器启动服务器
    python_exec = find_python_executable()
    
    # 启动服务器进程
    try:
        server_process = subprocess.Popen([python_exec, server_path])
        print(f"服务器已启动 (PID: {server_process.pid})")
        return server_process
    except Exception as e:
        print(f"启动服务器时出错: {e}")
        return None

def handle_shutdown(server_process):
    """处理关闭"""
    def signal_handler(sig, frame):
        print("\n正在关闭服务器...")
        if server_process and server_process.poll() is None:
            if sys.platform == 'win32':
                # Windows 使用 taskkill 终止进程及其子进程
                subprocess.run(['taskkill', '/F', '/T', '/PID', str(server_process.pid)], 
                              capture_output=True)
            else:
                # Linux/Mac 使用 SIGTERM 信号
                server_process.send_signal(signal.SIGTERM)
                server_process.wait(timeout=5)
        print("服务器已关闭")
        sys.exit(0)
    
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

def main():
    """主函数"""
    # 切换到脚本所在目录
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)
    
    print("=" * 50)
    print("TTS Companion 服务端启动工具")
    print("=" * 50)
    
    # 检查依赖
    if not check_requirements():
        print("缺少必要依赖，请安装后再试")
        return
    
    # 检查并关闭已存在的服务
    check_and_kill_existing_server()
    
    # 启动服务器
    server_process = start_server()
    if not server_process:
        return
    
    # 注册信号处理
    handle_shutdown(server_process)
    
    print("\n服务器正在运行中...")
    print("按 Ctrl+C 停止服务器")
    
    # 保持脚本运行
    try:
        while server_process.poll() is None:
            time.sleep(1)
        
        # 如果服务器意外终止
        exit_code = server_process.returncode
        print(f"服务器已终止 (退出码: {exit_code})")
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main() 