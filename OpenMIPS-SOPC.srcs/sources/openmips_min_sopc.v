`timescale 1ns / 1ps
//******************************************************************************
//                      基于实践版OpenMIPS的小型SOPC
//******************************************************************************

`include "openmips/defines.v"

module openmips_min_sopc(
    input wire rst,
    input wire clk,

    //UART接口
    input wire uart_in,                         //串口输入信号
    output wire uart_out,                       //串口输出信号

    //GPIO接口
    input wire[15:0] gpio_i,                    //GPIO的16位输入接口
    output wire[31:0] gpio_o,                   //GPIO的32位输出接口

    //与外部Flash相连的接口
    input wire[7:0] flash_data_i,               //从Flash读出的数据
    output wire[21:0] flash_addr_o,             //DE2平台上的Flash为4MB
    output wire flash_we_o,                     //Flash写使能信号，低电平有效
    output wire flash_rst_o,                    //Flash复位信号，低电平有效
    output wire flash_oe_o,                     //Flash输出使能信号，低电平有效
    output wire flash_ce_o,                     //Flash片选信号，低电平有效

    //与外部SDRAM相连的接口
    output wire sdr_clk_o,                      //SDRAM时钟信号
    output wire sdr_cs_n_o,                     //SDRAM片选信号，低电平有效
    output wire sdr_cke_o,                      //SDRAM时钟使能信号
    output wire sdr_ras_n_o,                    //SDRAM行地址选通信号，低电平有效
    output wire sdr_cas_n_o,                    //SDRAM列地址选通信号，低电平有效
    output wire sdr_we_n_o,                     //SDRAM写操作信号，低电平有效
    output wire[1:0] sdr_dqm_o,                 //SDRAM字节选择和输出使能，低电平有效
    output wire[1:0] sdr_ba_o,                  //SDRAM的Bank选择信号
    output wire[12:0] sdr_addr_o,               //SDRAM地址总线
    inout wire[15:0] sdr_dq_io                  //SDRAM数据总线
    );

    //中断相关信号
    wire[5:0] int;                              //外部中断
    wire timer_int;                             //时钟中断
    wire gpio_int;
    wire uart_int;

    //GPIO模块输入信号
    wire[31:0] gpio_i_temp;

    //SDRAM初始化完成信号
    wire sdram_init_done;

//******************************************************************************
//              Wishbone总线互联矩阵WB_CONMAX与各个模块的连接线
//******************************************************************************

    //主设备接口0：数据Wishbone总线接口
    wire[31:0] m0_data_i;
    wire[31:0] m0_data_o;
    wire[31:0] m0_addr_i;
    wire[3:0] m0_sel_i;
    wire m0_we_i;
    wire m0_cyc_i;
    wire m0_stb_i;
    wire m0_ack_o;

    //主设备接口1：指令Wishbone总线接口
    wire[31:0] m1_data_i;
    wire[31:0] m1_data_o;
    wire[31:0] m1_addr_i;
    wire[3:0] m1_sel_i;
    wire m1_we_i;
    wire m1_cyc_i;
    wire m1_stb_i;
    wire m1_ack_o;

    //从设备接口0：SDRAM控制器
    wire[31:0] s0_data_i;
    wire[31:0] s0_data_o;
    wire[31:0] s0_addr_o;
    wire[3:0] s0_sel_o;
    wire s0_we_o;
    wire s0_cyc_o;
    wire s0_stb_o;
    wire s0_ack_i;

    //从设备接口1：UART控制器
    wire[31:0] s1_data_i;
    wire[31:0] s1_data_o;
    wire[31:0] s1_addr_o;
    wire[3:0] s1_sel_o;
    wire s1_we_o;
    wire s1_cyc_o;
    wire s1_stb_o;
    wire s1_ack_i;

    //从设备接口2：GPIO
    wire[31:0] s2_data_i;
    wire[31:0] s2_data_o;
    wire[31:0] s2_addr_o;
    wire[3:0] s2_sel_o;
    wire s2_we_o;
    wire s2_cyc_o;
    wire s2_stb_o;
    wire s2_ack_i;

    //从设备接口3：Flash控制器
    wire[31:0] s3_data_i;
    wire[31:0] s3_data_o;
    wire[31:0] s3_addr_o;
    wire[3:0] s3_sel_o;
    wire s3_we_o;
    wire s3_cyc_o;
    wire s3_stb_o;
    wire s3_ack_i;


    assign sdr_clk_o = clk;

    //OpenMIPS处理器的中断输入，此处有时钟中断、UART中断、GPIO中断
    assign int = {3'b000,gpio_int,uart_int,timer_int};

    //将SDRAM控制器的输出sdram_init_done也作为GPIO的一个输入，处理器可以通过读取GPIO
    //的输入值，判断其第16bit是否为1，从而知道SDRAM是否初始化完毕
    assign gpio_i_temp = {15'h0000,sdram_init_done,gpio_i};

//******************************************************************************
//                         例化实践版OpenMIPS处理器
//******************************************************************************
    openmips openmips0(
        .rst(rst),
        .clk(clk),

        //指令Wishbone总线接口连接到Wishbone总线互联矩阵的主设备接口1
        .iwishbone_addr_o(m1_addr_i),
        .iwishbone_data_i(m1_data_o),
        .iwishbone_data_o(m1_data_i),
        .iwishbone_we_o(m1_we_i),
        .iwishbone_sel_o(m1_sel_i),
        .iwishbone_cyc_o(m1_cyc_i),
        .iwishbone_stb_o(m1_stb_i),
        .iwishbone_ack_i(m1_ack_o),

        //数据Wishbone总线接口连接到Wishbone总线互联矩阵的主设备接口0
        .dwishbone_addr_o(m0_addr_i),
        .dwishbone_data_i(m0_data_o),
        .dwishbone_data_o(m0_data_i),
        .dwishbone_we_o(m0_we_i),
        .dwishbone_sel_o(m0_sel_i),
        .dwishbone_cyc_o(m0_cyc_i),
        .dwishbone_stb_o(m0_stb_i),
        .dwishbone_ack_i(m0_ack_o),

        //外部中断和时钟中断
        .int_i(int),
        .timer_int_o(timer_int)
        );

//******************************************************************************
//                              例化GPIO
//******************************************************************************
    gpio_top gpio_top0(
        //GPIO连接到Wishbone总线互联矩阵的从设备接口2
        .wb_clk_i(clk),
        .wb_rst_i(rst),
        .wb_cyc_i(s2_cyc_o),
        .wb_adr_i(s2_addr_o[7:0]),
        .wb_dat_i(s2_data_o),
        .wb_sel_i(s2_sel_o),
        .wb_we_i(s2_we_o),
        .wb_stb_i(s2_stb_o),
    	.wb_dat_o(s2_data_i),
        .wb_ack_o(s2_ack_i),
        .wb_err_o(),

        .wb_inta_o(gpio_int),
        .ext_pad_i(gpio_i_temp),
        .ext_pad_o(gpio_o),                 //连接到32位GPIO输出接口
        .ext_padoe_o()
        );

//******************************************************************************
//                            例化Flash控制器
//******************************************************************************
    flash_top flash_top0(
        //Flash控制器连接到Wishbone总线互联矩阵的从设备接口3
        //Wishbone总线接口
        .wb_rst_i(rst),
        .wb_clk_i(clk),
        .wb_adr_i(s3_addr_o),
        .wb_dat_o(s3_data_i),
        .wb_dat_i(s3_data_o),
        .wb_sel_i(s3_sel_o),
        .wb_we_i(s3_we_o),
        .wb_cyc_i(s3_cyc_o),
        .wb_stb_i(s3_stb_o),
        .wb_ack_o(s3_ack_i),

        //Flash芯片接口
        .flash_adr_o(flash_addr_o),
        .flash_dat_i(flash_data_i),
        .flash_rst(flash_rst_o),
        .flash_oe(flash_oe_o),
        .flash_ce(flash_ce_o),
        .flash_we(flash_we_o)
        );

//******************************************************************************
//                            例化UART控制器
//******************************************************************************
    uart_top uart_top0(
        //UART控制器连接到Wishbone总线互联矩阵的从设备接口1
        .wb_clk_i(clk),
    	.wb_rst_i(rst),
        .wb_adr_i(s1_addr_o[4:0]),
        .wb_dat_i(s1_data_o),
        .wb_dat_o(s1_data_i),
        .wb_we_i(s1_we_o),
        .wb_stb_i(s1_stb_o),
        .wb_cyc_i(s1_cyc_o),
        .wb_ack_o(s1_ack_i),
        .wb_sel_i(s1_sel_o),

        //串口中断
    	.int_o(uart_int),

    	//UART接口
    	//serial input/output
    	.stx_pad_o(uart_out),        //串口输出
        .srx_pad_i(uart_in),         //串口输入
    	//modem signals
    	.rts_pad_o(),                //RTS(Request To Send)请求发送信号
        .cts_pad_i(1'b0),            //CTS(Clear To Send)清除发送信号
        .dtr_pad_o(),                //DTR(Data Terminal Ready)数据终端准备好信号
        .dsr_pad_i(1'b0),            //DSR(Data Set Ready)数据准备好信号
        .ri_pad_i(1'b0),             //RI(Ring Indicator)振铃指示信号
        .dcd_pad_i(1'b0)             //DCD(Data Carrier Detect)数据载波检测信号
        );

//******************************************************************************
//                            例化SDRAM控制器
//******************************************************************************
    sdrc_top sdrc_top0(
        //SDRAM控制器连接到Wishbone总线互联矩阵的从设备接口0
        .wb_rst_i(rst),
        .wb_clk_i(clk),
        .wb_stb_i(s0_stb_o),
        .wb_ack_o(s0_ack_i),
        .wb_addr_i({s0_addr_o[25:2],2'b00}),    //sdrc_top源码中地址总线为26位
        .wb_we_i(s0_we_o),
        .wb_dat_i(s0_data_o),
        .wb_sel_i(s0_sel_o),
        .wb_dat_o(s0_data_i),
        .wb_cyc_i(s0_cyc_o),
        .wb_cti_i(3'b000),               //Wishbone B3版本才添加的信号(此处不使用)

        //与SOPC外部接口相连，对外连接SDRAM
        .sdram_clk(clk),
        .sdram_resetn(~rst),
        .sdr_cs_n(sdr_cs_n_o),
        .sdr_cke(sdr_cke_o),
        .sdr_ras_n(sdr_ras_n_o),
        .sdr_cas_n(sdr_cas_n_o),
        .sdr_we_n(sdr_we_n_o),
        .sdr_dqm(sdr_dqm_o),
        .sdr_ba(sdr_ba_o),
        .sdr_addr(sdr_addr_o),
        .sdr_dq(sdr_dq_io),

//*******************SDRAM控制器的一些配置，具体芯片具体分析***********************
//DE2的SDRAM为Zentel公司的A3V64S40ETP-G6，大小为8MB，数据宽度为16位，有4个Bank

        //SDRAM的数据总线宽度：00为32位SDRAM;01为16位SDRAM;1x为8位SDRAM
        .cfg_sdr_width(2'b01),

        //列地址宽度：00-8bit;01-9bit;10-10bit;11-11bit
        .cfg_colbits(2'b00),

        //请求缓存的数量
        .cfg_req_depth(2'b11),

        //SDRAM控制器使能信号
        .cfg_sdr_en(1'b1),

        //模式寄存器
        //模式寄存器配置为13'b0000000110001，表示CAS延迟为3个时钟周期，突发长度为2
        //(一次读出16bit，2次正好是32bit)，突发模式是线性(Linear)
        .cfg_sdr_mode_reg(13'b000_0_00_011_0_001),

        //时间tRAS的值，单位是时钟周期
        //时间tRAS(Active to Precharge Command)表示ACT命令与预充电命令之间的时间
        //间隔。预充电命令至少要在行有效命令5个时钟周期后发出，最长间隔视芯片而异，否则
        //工作行有丢失的危险
        .cfg_sdr_tras_d(4'b1000),

        //时间tRP的值，单位是时钟周期
        //tRP(Precharge Command Period)：预充电命令后，需要相隔tRP时间，才可以打开新
        //的行
        .cfg_sdr_trp_d(4'b0010),

        //时间tRCD的值，单位是时钟周期
        //tRCD(RAS to CAS Delay)：ACT命令执行完毕后，还不可以立即进行读、写操作，需要
        //等待一段时间。一般占用2-3个时钟周期
        .cfg_sdr_trcd_d(4'b0010),

        //时间CL的值，单位是时钟周期
        //CL(CAS Latency)表示CAS延迟，指的是从READ命令发出到第一次数据输出之间的时间，
        //通常设定为2或3个时钟周期
        .cfg_sdr_cas(3'b100),

        //时间tRC的值，单位是时钟周期
        //tRC(Row Cycle time)表示SDRAM行周期时间，它是包括行预充电到激活在内的整个
        //过程所需要的最小时钟周期数，一般而言，tRC=tRAS+tRP
        .cfg_sdr_trcar_d(4'b1010),

        //时间tWR的值，单位是时钟周期
        //tWR(Write Recovery time)表示写入/矫正时间：在执行写操作时，数据并不是即时地
        //写入存储电容，因为选通三极管与电容的充电必须要有一段时间，所以数据的真正写入
        //要有一定的周期，为了保证数据的可靠写入，需要留出足够的时间，也就是此处的tWR，
        //一般大于等于1个时钟周期
        .cfg_sdr_twr_d(4'b0010),

        //自动刷新命令之间的时间间隔，单位是时钟周期
        //存储体中电容的数据有效保存期的上限是64ms，也就是每一行的刷新循环周期最多是
        //64ms，刷新间隔的计算方法是：64ms/(行数量/每次刷新最大行数)，再根据该时间
        //等于多少个时钟周期数设置cfg_sdr_rfsh的值
        .cfg_sdr_rfsh(12'b011010011000),

        //每次刷新的最大行数
        .cfg_sdr_rfmax(3'b100),

        //SDRAM初始化完毕信号，通过GPIO的输入接口传给处理器
        .sdr_init_done(sdram_init_done)
        );

//******************************************************************************
//                        例化Wishbone总线互联矩阵
//******************************************************************************
    wb_conmax_top wb_conmax_top0(
        .clk_i(clk),
        .rst_i(rst),

        //主设备接口0：连接OpenMIPS处理器的数据Wishbone总线接口
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_addr_i(m0_addr_i),
        .m0_sel_i(m0_sel_i),
        .m0_we_i(m0_we_i),
        .m0_cyc_i(m0_cyc_i),
    	.m0_stb_i(m0_stb_i),
        .m0_ack_o(m0_ack_o),

        //主设备接口1：连接OpenMIPS处理器的指令Wishbone总线接口
        .m1_data_i(m1_data_i),
        .m1_data_o(m1_data_o),
        .m1_addr_i(m1_addr_i),
        .m1_sel_i(m1_sel_i),
        .m1_we_i(m1_we_i),
        .m1_cyc_i(m1_cyc_i),
        .m1_stb_i(m1_stb_i),
        .m1_ack_o(m1_ack_o),

        //主设备接口2
        .m2_data_i(`ZeroWord),
        .m2_data_o(),
        .m2_addr_i(`ZeroWord),
        .m2_sel_i(4'b0000),
        .m2_we_i(1'b0),
        .m2_cyc_i(1'b0),
        .m2_stb_i(1'b0),
        .m2_ack_o(),
        .m2_err_o(),
        .m2_rty_o(),

        //主设备接口3
        .m3_data_i(`ZeroWord),
        .m3_data_o(),
        .m3_addr_i(`ZeroWord),
        .m3_sel_i(4'b0000),
        .m3_we_i(1'b0),
        .m3_cyc_i(1'b0),
        .m3_stb_i(1'b0),
        .m3_ack_o(),
        .m3_err_o(),
        .m3_rty_o(),


        //主设备接口4
        .m4_data_i(`ZeroWord),
        .m4_data_o(),
        .m4_addr_i(`ZeroWord),
        .m4_sel_i(4'b0000),
        .m4_we_i(1'b0),
        .m4_cyc_i(1'b0),
        .m4_stb_i(1'b0),
        .m4_ack_o(),
        .m4_err_o(),
        .m4_rty_o(),

        //主设备接口5
        .m5_data_i(`ZeroWord),
        .m5_data_o(),
        .m5_addr_i(`ZeroWord),
        .m5_sel_i(4'b0000),
        .m5_we_i(1'b0),
        .m5_cyc_i(1'b0),
        .m5_stb_i(1'b0),
        .m5_ack_o(),
        .m5_err_o(),
        .m5_rty_o(),

        //主设备接口6
        .m6_data_i(`ZeroWord),
        .m6_data_o(),
        .m6_addr_i(`ZeroWord),
        .m6_sel_i(4'b0000),
        .m6_we_i(1'b0),
        .m6_cyc_i(1'b0),
        .m6_stb_i(1'b0),
        .m6_ack_o(),
        .m6_err_o(),
        .m6_rty_o(),

        //主设备接口7
        .m7_data_i(`ZeroWord),
        .m7_data_o(),
        .m7_addr_i(`ZeroWord),
        .m7_sel_i(4'b0000),
        .m7_we_i(1'b0),
        .m7_cyc_i(1'b0),
        .m7_stb_i(1'b0),
        .m7_ack_o(),
        .m7_err_o(),
        .m7_rty_o(),


        //从设备接口0：连接到SDRAM控制器
        .s0_data_i(s0_data_i),
        .s0_data_o(s0_data_o),
        .s0_addr_o(s0_addr_o),
        .s0_sel_o(s0_sel_o),
        .s0_we_o(s0_we_o),
        .s0_cyc_o(s0_cyc_o),
    	.s0_stb_o(s0_stb_o),
        .s0_ack_i(s0_ack_i),
        .s0_err_i(1'b0),
        .s0_rty_i(1'b0),

        //从设备接口1：连接到UART控制器
        .s1_data_i(s1_data_i),
        .s1_data_o(s1_data_o),
        .s1_addr_o(s1_addr_o),
        .s1_sel_o(s1_sel_o),
        .s1_we_o(s1_we_o),
        .s1_cyc_o(s1_cyc_o),
    	.s1_stb_o(s1_stb_o),
        .s1_ack_i(s1_ack_i),
        .s1_err_i(1'b0),
        .s1_rty_i(1'b0),

        //从设备接口2：连接到GPIO
        .s2_data_i(s2_data_i),
        .s2_data_o(s2_data_o),
        .s2_addr_o(s2_addr_o),
        .s2_sel_o(s2_sel_o),
        .s2_we_o(s2_we_o),
        .s2_cyc_o(s2_cyc_o),
    	.s2_stb_o(s2_stb_o),
        .s2_ack_i(s2_ack_i),
        .s2_err_i(1'b0),
        .s2_rty_i(1'b0),

        //从设备接口3：连接到Flash控制器
        .s3_data_i(s3_data_i),
        .s3_data_o(s3_data_o),
        .s3_addr_o(s3_addr_o),
        .s3_sel_o(s3_sel_o),
        .s3_we_o(s3_we_o),
        .s3_cyc_o(s3_cyc_o),
    	.s3_stb_o(s3_stb_o),
        .s3_ack_i(s3_ack_i),
        .s3_err_i(1'b0),
        .s3_rty_i(1'b0),

        //从设备接口4
        .s4_data_i(),
        .s4_data_o(),
        .s4_addr_o(),
        .s4_sel_o(),
        .s4_we_o(),
        .s4_cyc_o(),
    	.s4_stb_o(),
        .s4_ack_i(1'b0),
        .s4_err_i(1'b0),
        .s4_rty_i(1'b0),

        //从设备接口5
        .s5_data_i(),
        .s5_data_o(),
        .s5_addr_o(),
        .s5_sel_o(),
        .s5_we_o(),
        .s5_cyc_o(),
    	.s5_stb_o(),
        .s5_ack_i(1'b0),
        .s5_err_i(1'b0),
        .s5_rty_i(1'b0),

        //从设备接口6
        .s6_data_i(),
        .s6_data_o(),
        .s6_addr_o(),
        .s6_sel_o(),
        .s6_we_o(),
        .s6_cyc_o(),
    	.s6_stb_o(),
        .s6_ack_i(1'b0),
        .s6_err_i(1'b0),
        .s6_rty_i(1'b0),

        //从设备接口7
        .s7_data_i(),
        .s7_data_o(),
        .s7_addr_o(),
        .s7_sel_o(),
        .s7_we_o(),
        .s7_cyc_o(),
    	.s7_stb_o(),
        .s7_ack_i(1'b0),
        .s7_err_i(1'b0),
        .s7_rty_i(1'b0),

        //从设备接口8
        .s8_data_i(),
        .s8_data_o(),
        .s8_addr_o(),
        .s8_sel_o(),
        .s8_we_o(),
        .s8_cyc_o(),
    	.s8_stb_o(),
        .s8_ack_i(1'b0),
        .s8_err_i(1'b0),
        .s8_rty_i(1'b0),

        //从设备接口9
        .s9_data_i(),
        .s9_data_o(),
        .s9_addr_o(),
        .s9_sel_o(),
        .s9_we_o(),
        .s9_cyc_o(),
    	.s9_stb_o(),
        .s9_ack_i(1'b0),
        .s9_err_i(1'b0),
        .s9_rty_i(1'b0),

        //从设备接口10
        .s10_data_i(),
        .s10_data_o(),
        .s10_addr_o(),
        .s10_sel_o(),
        .s10_we_o(),
        .s10_cyc_o(),
    	.s10_stb_o(),
        .s10_ack_i(1'b0),
        .s10_err_i(1'b0),
        .s10_rty_i(1'b0),

        //从设备接口11
        .s11_data_i(),
        .s11_data_o(),
        .s11_addr_o(),
        .s11_sel_o(),
        .s11_we_o(),
        .s11_cyc_o(),
        .s11_stb_o(),
        .s11_ack_i(1'b0),
        .s11_err_i(1'b0),
        .s11_rty_i(1'b0),

        //从设备接口12
        .s12_data_i(),
        .s12_data_o(),
        .s12_addr_o(),
        .s12_sel_o(),
        .s12_we_o(),
        .s12_cyc_o(),
    	.s12_stb_o(),
        .s12_ack_i(1'b0),
        .s12_err_i(1'b0),
        .s12_rty_i(1'b0),

        //从设备接口13
        .s13_data_i(),
        .s13_data_o(),
        .s13_addr_o(),
        .s13_sel_o(),
        .s13_we_o(),
        .s13_cyc_o(),
        .s13_stb_o(),
        .s13_ack_i(1'b0),
        .s13_err_i(1'b0),
        .s13_rty_i(1'b0),

        //从设备接口14
        .s14_data_i(),
        .s14_data_o(),
        .s14_addr_o(),
        .s14_sel_o(),
        .s14_we_o(),
        .s14_cyc_o(),
        .s14_stb_o(),
        .s14_ack_i(1'b0),
        .s14_err_i(1'b0),
        .s14_rty_i(1'b0),

        //从设备接口15
        .s15_data_i(),
        .s15_data_o(),
        .s15_addr_o(),
        .s15_sel_o(),
        .s15_we_o(),
        .s15_cyc_o(),
    	.s15_stb_o(),
        .s15_ack_i(1'b0),
        .s15_err_i(1'b0),
        .s15_rty_i(1'b0)
        );

endmodule
