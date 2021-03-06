f=imread('16.tif');%读取图像到内存
%f=imresize(f,[363,312]);%该函数用于对图像做缩放处理。
%figure;imshow(f);
%用rgb2gray 将彩色图像转换为灰度图像。matlab读入图像的数据是uint8，而matlab中数值一般采用double型（64位）存储和运算。
%所以要先将图像转为double格式的才能运算
gray=double((f));
%转成uint8 imshow()显示图像时对double型是认为在0~1范围内即大于1时都是显示为白色，而imshow显示uint8型时是0~255范围。
%所以对double类型的图像显示的时候，要么归一化到0~1之间，要么将double类型的0~255数据转为uint8类型。
%figure;imshow(uint8(gray));

%归一化，灰度值限制在某一范围
M=0;var=0;
%均值
m=size(gray,1);n=size(gray,2);
for x=1:m
    for y=1:n
        M=M+gray(x,y);
    end
end
M1=M/(m*n);%M1为均值 所有像素总共和除以多少个像素
%方差
for x=1:m
    for y=1:n
        var=var+(gray(x,y)-M1).^2;
    end;
end;
var1=var/(m*n);%计算方差最终的大小 var1
%归一化 ********************************
for x=1:m
    for y=1:n
        if gray(x,y)>M1
            gray(x,y)=150+sqrt(2000*(gray(x,y)-M1)/var1);
        else
            gray(x,y)=150-sqrt(2000*(M1-gray(x,y))/var1);
        end
    end
end
%figure;imshow(uint8(gray));

%*************************************************************************************************************
%归一化处理完毕后会对图像进行分割处理，目的是区分出前景色和背景色。我采用的分割为根据多区域阈值分割。
%多区域分割的效果取决于区域的大小，而指纹的区域分为一脊一谷最好，所以我选择3x3的区域大小。我会根据对区域多次进行求均值和方差进行分割。
%分割 分成多个3*3的块大小 
M=3;
H=floor(m/M);L=floor(n/M);
aveg1=zeros(H,L);
var1=zeros(H,L);
%计算每一块的平均值
for x=1:H
    for y=1:L
        aveg=0;var=0;
        %每一块的均值
        for i=1:M
            for j=1:M
                aveg=gray(i+(x-1)*M,j+(y-1)*M)+aveg;
            end;
        end;
        aveg1(x,y)=aveg/(M*M);
        %每一块的方差值
        for i=1:M
            for j=1:M
                var=(gray(i+(x-1)*M,j+(y-1)*M)-aveg1(x,y)).^2+var;
            end;
        end;
        var1(x,y)=var/(M*M);
    end;
end;
%所有块的平均值和方差
Gmean=0;Vmean=0;
for x=1:H
    for y=1:L
        Gmean=Gmean+aveg1(x,y);
        Vmean=Vmean+var1(x,y);
    end
end
Gmean1=Gmean/(H*L);
Vmean1=Vmean/(H*L);

%每一小块和整块相比，再次求均值方差
% 前景（黑色）
gtemp=0;gtotle=0;vtotle=0;vtemp=0;
for x=1:H
    for y=1:L
        if Gmean1>aveg1(x,y)%如果当前快的均值小于全局均值 就认为是前景 
            gtemp=gtemp+1;
            gtotle=gtotle+aveg1(x,y);
        end
        if Vmean1<var1(x,y)%如果当前快的方差大于全局方差 认为是前景
            vtemp=vtemp+1;
            vtotle=vtotle+var1(x,y);
        end
    end
end
% 前景均值
G1=gtotle/gtemp;
% 前景方差
V1=vtotle/vtemp;

%再次与刚刚产生的值相比
% 求得背景（白色）均值方差 增加可靠性
gtemp1=0;gtotle1=0;vtotle1=0;vtemp1=0;
for x=1:H
    for y=1:L
        if G1<aveg1(x,y)%如果当前快的均值大于前景的均值 就认为是背景
            gtemp1=gtemp1+1;
            gtotle1=gtotle1+aveg1(x,y);
        end
        if 0<var1(x,y)<V1%如果当前的方差小于前景的方差 就认为是背景
            vtemp1=vtemp1+1;
            vtotle1=vtotle1+var1(x,y);
        end
    end
end
% 背景均值
G2=gtotle1/gtemp1;
% 背景方差
V2=vtotle1/vtemp1;
%我会根据对区域多次进行求均值和方差进行分割。采集到的指纹图背景的灰度值大于前景色，背景主要为低频，所以背景的方差小于前景的方差。
%我分别求得背景和前景的均值和方差然后会得到背景为白色 脊线为黑色。
%然后保存在矩阵e（二值图）中，我会根据e中位置等于1的点的八邻域点的和小于四得到背景色，达到背景和前景分离（e矩阵）。
%****************************************
%构建矩阵（H*L）
e=zeros(H,L);
for x=1:H
    for y=1:L
        if aveg1(x,y)>G2 && var1(x,y)<V2 %当前的小块的值 大于背景均值 且当前小块的方差小于背景方差 
            %   背景
            e(x,y)=1;
        end
        %  前景中的更接近黑色的变为白色
        if aveg1(x,y)<G1-100 && var1(x,y)<V2
            e(x,y)=1;
        end
    end
end




%该点八邻域小于四为0
%根据e中位置等于1的点的八邻域点的和小于四得到背景色，达到背景和前景分离（e矩阵）
for x=2:H-1
    for y=2:L-1
        if e(x,y)==1
            if e(x-1,y) + e(x,y+1)+e(x+1,y+1)+e(x-1,y+1)+e(x+1,y)+e(x+1,y-1)+e(x,y-1)+e(x-1,y-1) <=4
                e(x,y)=0;
            end
        end
    end
end
%然后黑白反转让感兴趣的前景色变为白色（保存在Icc中），灰度图（gray）的背景值替换为小区域块的和的均值（G1）.
%构建m*m矩阵
Icc=ones(m,n);
for x=1:H
    for y=1:L
        if e(x,y)==1 %如果 当前 是 1 是我们想要的
            for i=1:M
                for j=1:M
                    gray(i+(x-1)*M,j+(y-1)*M)=G1;
                    Icc(i+(x-1)*M,j+(y-1)*M)=0;
                end
            end
        end
    end
end
%figure,imshow(uint8(gray));
%figure,imshow(Icc);

%找指纹脊线方向并二值化

%*******************************
%*噪声对图像处理的影响很大，它影响图像处理的输入、采集和处理等各个环节以及输出结果。因此，在进行其它的图像处理前，需要对图像进行去噪处理。
%*均值滤波方法是，对待处理的当前像素，选择一个模板，该模板为其邻近的若干个像素组成，用模板的均值来替代原像素的值的方法。
temp=(1/9)*[1,1,1;1,1,1;1,1,1];%模板系数  均值滤波
Im=gray;
In=zeros(m,n);
for a=2:m-1
    for b=2:n-1
        In(a,b)=Im(a-1,b-1)*temp(1,1)+Im(a-1,b)*temp(1,2)+Im(a-1,b+1)*temp(1,3)+Im(a,b-1)*temp(2,1)...
            +Im(a,b)*temp(2,2)+Im(a,b+1)*temp(2,3)+Im(a+1,b-1)*temp(3,1)+Im(a+1,b)*temp(3,2)+Im(a+1,b+1)*temp(3,3);
    end
end
gray=In;%平滑后的图像矩阵
Im=zeros(m,n);
%为了估计脊线的方向场，把脊线的方向场划分为八个方向，然后根据八个方向的灰度值的总和来得到脊线的方向。并对图像进行二值化。
%求八个方向每个方向的和
for x=5:m-5
    for y=5:n-5
        %0-7方向的和
        sum1=gray(x,y-4)+gray(x,y-2)+gray(x,y+2)+gray(x,y+4);
        sum2=gray(x-2,y+4)+gray(x-1,y+2)+gray(x+1,y-2)+gray(x+2,y-4);
        sum3=gray(x-2,y+2)+gray(x-4,y+4)+gray(x+2,y-2)+gray(x+4,y-4);
        sum4=gray(x-2,y+1)+gray(x-4,y+2)+gray(x+2,y-1)+gray(x+4,y-2);
        sum5=gray(x-2,y)+gray(x-4,y)+gray(x+2,y)+gray(x+4,y);
        sum6=gray(x-4,y-2)+gray(x-2,y-1)+gray(x+2,y+1)+gray(x+4,y+2);
        sum7=gray(x-4,y-4)+gray(x-2,y-2)+gray(x+2,y+2)+gray(x+4,y+4);
        sum8=gray(x-2,y-4)+gray(x-1,y-2)+gray(x+1,y+2)+gray(x+2,y+4);
        sumi=[sum1,sum2,sum3,sum4,sum5,sum6,sum7,sum8];
        %最大值
        summax=max(sumi);
        %最小值
        summin=min(sumi);
        %和 &&平均值
        summ=sum(sumi);
        b=summ/8;
        
        if(summax+summin+4*gray(x,y))> (3*b)
            sumf=summin;
        else
            sumf=summax;
        end
        
        if sumf>b
            Im(x,y)=128;
        else
            Im(x,y)=255;
        end
    end
end
% imshow(Im);


%两个矩阵点乘 Icc 白色的是感兴趣的像素 黑色的 0 表示的是边缘 不感兴趣的，需要略掉
for i=1:m
    for j=1:n
        Icc(i,j)=Icc(i,j)*Im(i,j);
    end
end
%转换为二值图
for i=1:m
    for j=1:n
        if (Icc(i,j)==128)
            Icc(i,j)=0;
        else
            Icc(i,j)=1;
        end
    end
end
%figure;imshow(double(Icc));
%title('Icc');

%去除空洞和毛刺
u=Icc;
for x=2:m-1
    for y=2:n-1
        if u(x,y)==0
            %该点的4邻域点（上下左右） 如果三个或以上都是白点（1）则该点为毛刺
            if u(x,y-1)+u(x-1,y)+u(x,y+1)+u(x+1,y)>=3
                u(x,y)=1;
            end
        else
            u(x,y)=u(x,y);
        end
    end
end
%figure;imshow(u);
%title('去除毛刺');
%去除空洞
for a=2:m-1
    for b=2:n-1
        if u(a,b)==1
            %寻找端点
            if abs(u(a,b+1)-u(a-1,b+1))+abs(u(a-1,b+1)-u(a-1,b))+abs(u(a-1,b)-u(a-1,b-1))...
                    +abs(u(a-1,b-1)-u(a,b-1))+(abs(u(a,b-1)-u(a+1,b-1)))+abs(u(a+1,b-1)-u(a+1,b))...
                    +abs(u(a+1,b)-u(a+1,b+1))+abs(u(a+1,b+1)-u(a,b+1))~=1
                if (u(a,b+1)+u(a-1,b+1)+u(a-1,b))*(u(a,b-1)+u(a+1,b-1)+u(a+1,b))+(u(a-1,b)+u(a-1,b-1)+u(a,b-1))...
                        *(u(a+1,b)+u(a+1,b+1)+u(a,b+1))==0
                    %去除空洞
                    u(a,b)=0;
                end
            end
        end
    end
end

%figure;imshow(u);
%title('去除空洞');
imdata=u;
for i=1:size(imdata,1)
    flag=0;
    for j=1:size(imdata,2)
        if (imdata(i,j)==0)
            flag=flag+1;
        end
    end
    if(flag>=10)
        fringe_x1=i;
        break;
    end
end
for i=size(imdata,1):-1:1
     flag=0;
    for j=1:size(imdata,2)
        if (imdata(i,j)==0)
            flag=flag+1;
        end
    end
    if(flag>=10)
        fringe_x2=i;
        break;
    end
end
for i=1:size(imdata,2)
         flag=0;
    for j=1:size(imdata,1)
        if (imdata(j,i)==0)
            flag=flag+1;
        end
    end
    if(flag>=10)
        fringe_y1=i;
        break;
    end
end
for i=size(imdata,2):-1:1
          flag=0;
    for j=1:size(imdata,1)
        if (imdata(j,i)==0)
            flag=flag+1;
        end
    end
    if(flag>=10)
        fringe_y2=i;
        break;
    end
end
image=imdata(  fringe_x1:   fringe_x2 ,fringe_y1:  fringe_y2);
%figure;imshow(image);
%title('xxx');
image1=imresize(image,[350,200]);
%figure;imshow(image1);
%title('xxx');
imwrite(image1,'result16.tif')
%figure;imshow('result01.tif');
% %图像细化
% v=~u;
% figure;imshow(v);
% se=strel('square',3);%用于膨胀腐蚀及开闭运算等操作的结构元素对象
% 
% % 形态学运算中腐蚀，膨胀，开运算和闭运算。
% % 
% % 1. 腐蚀是一种消除边界点，使边界向内部收缩的过程。可以用来消除小且无意义的物体。
% % 腐蚀的算法：
% % 用3x3的结构元素，扫描图像的每一个像素
% % 用结构元素与其覆盖的二值图像做“与”操作
% % 如果都为1，结果图像的该像素为1。否则为0。
% % 结果：使二值图像减小一圈
% % 
% % 2. 膨胀是将与物体接触的所有背景点合并到该物体中，使边界向外部扩张的过程。可以用来填补物体中的空洞。
% % 膨胀的算法：
% % 用3x3的结构元素，扫描图像的每一个像素
% % 用结构元素与其覆盖的二值图像做“与”操作
% % 如果都为0，结果图像的该像素为0。否则为1
% % 结果：使二值图像扩大一圈
% % 
% % 
% % 3. 先腐蚀后膨胀的过程称为开运算。用来消除小物体、在纤细点处分离物体、平滑较大物体的边界的同时并不明显改变其面积。
% % 4. 先膨胀后腐蚀的过程称为闭运算。用来填充物体内细小空洞、连接邻近物体、平滑其边界的同时并不明显改变其面积。
% %  
% %对图像进行开闭操作
% fo=imopen(v,se);
% figure;imshow(fo);
% % 先腐蚀后膨胀，作用是：可以使边界平滑，消除细小的尖刺，断开窄小的连接,保持面积大小不变
% title('开运算')
% v=imclose(fo,se);
% figure;imshow(v);
% title('闭运算')
% w=bwmorph(v,'thin',Inf);%对图像进行细化
% figure;imshow(w);
% title('细化图');
