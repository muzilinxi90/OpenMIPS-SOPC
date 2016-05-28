`timescale 1ns / 1ps
//******************************************************************************
//                              Flash控制器
//  在有读取Flash的请求时(读指令请求)，分四次从Flash中读取出四个字节，组成一条指令。每
//读取一个字节需要3个时钟周期。在大端模式下，首先读取到的字节对应的是指令的MSB。
//******************************************************************************

module flash_top(
    //Wishbone总线接口
    input wire wb_rst_i,                        //Wishbone总线复位信号
    input wire wb_clk_i,                        //Wishbone总线时钟信号
    input wire[31:0] wb_adr_i,                  //从Wishbone总线输入到控制器的地址
    output reg[31:0] wb_dat_o,                  //从控制器输出到Wishbone总线的数据
    input wire[31:0] wb_dat_i,                  //从Wishbone总线输入到控制器的数据
    input wire[3:0] wb_sel_i,                   //Wishbone总线字节选择信号
    input wire wb_we_i,                         //Wishbone总线写使能信号
    input wire wb_cyc_i,                        //Wishbone总线周期信号
    input wire wb_stb_i,                        //Wishbone总线选通信号
    output reg wb_ack_o,                        //Wishbone总线输出的响应

    //Flash芯片接口
    output reg[31:0] flash_adr_o,               //Flash地址信号
    input wire[7:0] flash_dat_i,                //从Flash读出的数据
    output wire flash_rst,                      //Flash复位信号，低电平有效
    output wire flash_oe,                       //Flash输出使能信号，低电平有效
    output wire flash_ce,                       //Flash片选信号，低电平有效
    output wire flash_we                        //Flash写使能信号，低电平有效
    );

    wire wb_acc;                                //Wishbone access
    wire wb_rd;                                 //Wishbone read access
    reg[3:0] waitstate;                         //记录时钟周期数
    wire[1:0] adr_low;                          //???

    //如果Wishbone总线开始操作周期，那么设置变量wb_acc为1；
    //且在上述条件下，如果是读操作，那么设置变量wb_rd为1
    assign wb_acc = wb_cyc_i & wb_stb_i;
    assign wb_rd = wb_acc & !wb_we_i;

    //当变量wb_acc为1、wb_rd为1时，表示开始对Flash芯片的读操作。
    //所以设置输出信号flash_ce、flash_oe都为有效(低电平有效，因此设置为0)
    assign flash_ce = !wb_acc;
    assign flash_oe = !wb_rd;

    //因为不涉及对Flash芯片的写操作，所以输出信号flash_we始终设置为1，即读操作
    assign flash_we = 1'b1;

    //flash_rst也为低电平有效
    assign flash_rst = !wb_rst_i;

    always @ ( posedge wb_clk_i ) begin
        if(wb_rst_i == 1'b1) begin
            waitstate <= 4'h0;
            wb_ack_o <= 1'b0;
        end else if(wb_acc == 1'b0) begin       //wb_acc为0，表示没有访问请求
            waitstate <= 4'h0;
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'h0000_0000;
        end else if(waitstate == 4'h0) begin    //否则，有访问请求，开始读操作
            wb_ack_o <= 1'b0;
            if(wb_acc) begin
                waitstate <= waitstate + 4'h1;
            end
            //给出要读取的第一个字节的地址
            //书中使用的DE2平台上的Flash大小为4MB
            flash_adr_o <= {10'b0000000000,wb_adr_i[21:2],2'b0};
        end else begin
            //每个时钟走起将waitstate的值加1
            waitstate <= waitstate + 4'h1;

            if(waitstate == 4'h3) begin
                //为什么是3个时钟周期？Flash芯片手册？
                //经过3个时钟周期后，第一个字节读到，保存到wb_dat_o[31:24]
                wb_dat_o[31:24] <= flash_dat_i;
                //给出要读取的第二个字节的地址
                flash_adr_o <= {10'b0000000000,wb_adr_i[21:2],2'b01};
            end else if(waitstate == 4'h6) begin
                //再经过3个时钟周期后，第二个字节读到，保存到wb_dat_o[23:16]
                wb_dat_o[23:16] <= flash_dat_i;
                //给出要读取的第三个字节的地址
                flash_adr_o <= {10'b0000000000,wb_adr_i[21:2],2'b10};
            end else if(waitstate == 4'h9) begin
                //再经过3个时钟周期后，第三个字节读到，保存到wb_dat_o[15:8]
                wb_dat_o[15:8] <= flash_dat_i;
                //给出要读取的第四个字节的地址
                flash_adr_o <= {10'b0000000000,wb_adr_i[21:2],2'b11};
            end else if(waitstate == 4'hc) begin
                //再经过3个时钟周期后，第四个字节读到，保存到wb_dat_o[7:0]
                wb_dat_o[7:0] <= flash_dat_i;
                //wb_ack_o赋值为1，作为Wishbone总线操作的响应
                wb_ack_o <= 1'b1;
            end else if(waitstate == 4'hd) begin
                //经过1个时钟周期后，wb_ack_o赋值为0，Wishbone总线操作结束
                wb_ack_o <= 1'b0;
                waitstate <= 4'h0;
            end
        end
    end

endmodule
