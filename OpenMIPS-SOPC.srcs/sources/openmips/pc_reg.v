`timescale 1ns / 1ps
//******************************************************************************
//                        程序计数器PC，给出指令地址
//******************************************************************************

`include "defines.v"

module pc_reg(
    input wire rst,                     //复位信号
    input wire clk,                     //时钟信号

    output reg ce,                      //指令存储器访问请求信号
    output reg[`InstAddrBus] pc,        //要读取的指令地址

    //来自控制模块ctrl
    input wire[5:0] stall,
    input wire flush,                   //流水线清除信号
    input wire[`InstAddrBus] new_pc,    //异常处理例程入口地址

    //来自ID模块的信息(转移指令相关)
    input wire branch_flag_i,
    input wire[`InstAddrBus] branch_target_address_i
    );

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            ce <= `ChipDisable;
        end else begin
            ce <= `ChipEnable;
        end
    end


    always @ ( posedge clk ) begin
        //Flash控制器连接到从设备接口3，起始地址为0x30000000，系统启动(复位)后从Flash
        //读取第一条指令
        if(ce == `ChipDisable) begin
            pc <= 32'h3000_0000;
        //指令存储器使能时
        end else begin
            //输入信号flush为1表示异常发生，将从CTRL模块给出的异常处理例程入口地址
            //new_pc处取指执行
            if(flush == 1'b1) begin
                pc <= new_pc;
            //当stall[0]为NoStop时，PC加4或跳转；否则保持PC不变(流水线暂停)
            end else if(stall[0] == `NoStop) begin
                if(branch_flag_i == `Branch) begin
                    pc <= branch_target_address_i;
                end else begin
                    pc <= (pc + 32'h4);
                end
            end//else if(stall[0] == `NoStop)
        end//else(ce == `ChipEnable)
    end//always

endmodule
