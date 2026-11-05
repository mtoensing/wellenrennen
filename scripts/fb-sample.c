// Framebuffer cadence sampler. Reads stable front-page content; no GL access.
#define _POSIX_C_SOURCE 200809L
#include <linux/fb.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static double now(void) { struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9; }
int main(int argc,char**argv) {
 int fd=open("/dev/fb0",O_RDONLY);struct fb_fix_screeninfo fix;struct fb_var_screeninfo var;
 if(fd<0||ioctl(fd,FBIOGET_FSCREENINFO,&fix)||ioctl(fd,FBIOGET_VSCREENINFO,&var)){perror("fb");return 1;}
 if(var.bits_per_pixel!=32){fprintf(stderr,"requires 32-bit fb, got %u\n",var.bits_per_pixel);return 2;}
 unsigned char*mem=mmap(NULL,fix.smem_len,PROT_READ,MAP_SHARED,fd,0);
 if(mem==MAP_FAILED){perror("mmap");return 3;}
 printf("# fb %ux%u virtual=%ux%u bytes=%u stride=%u\n",var.xres,var.yres,var.xres_virtual,var.yres_virtual,fix.smem_len,fix.line_length);
 double start=now(),duration=argc>1?atof(argv[1]):5,last=start,maximum=0;uint64_t candidate=0,accepted=0;int stable=0,count=0;
 struct timespec delay={0,2000000};
 int vsync=getenv("FB_SAMPLE_VSYNC")!=NULL;
 while(now()-start<duration) {
  if(vsync){uint32_t crtc=0;if(ioctl(fd,FBIO_WAITFORVSYNC,&crtc)){perror("wait vsync");return 4;}}
  if(ioctl(fd,FBIOGET_VSCREENINFO,&var)){perror("fb page");break;}
  size_t offset=(size_t)var.yoffset*fix.line_length+(size_t)var.xoffset*4;
  if(offset+(var.yres-1)*fix.line_length+var.xres*4>fix.smem_len)break;
  uint64_t hash=1469598103934665603ULL;
  for(unsigned y=7;y<var.yres;y+=16)for(unsigned x=7;x<var.xres;x+=16) {
   volatile uint32_t*p=(volatile uint32_t*)(mem+offset+(size_t)y*fix.line_length+x*4);
   hash=(hash^(*p&0x00ffffffu))*1099511628211ULL;
  }
  if(hash==candidate)++stable;else{candidate=hash;stable=0;}
  if((vsync||stable==1)&&hash!=accepted){double t=now();double gap=t-last;if(count&&gap>maximum)maximum=gap;last=t;accepted=hash;++count;printf("%.6f %016llx\n",t-start,(unsigned long long)hash);
   if(argc>2 && count<=12) {
    char name[512];snprintf(name,sizeof(name),"%s-%02d.raw",argv[2],count);
    FILE*out=fopen(name,"wb");
    if(out){for(unsigned y=0;y<var.yres;++y)fwrite(mem+offset+(size_t)y*fix.line_length,4,var.xres,out);fclose(out);}
   }}
  nanosleep(&delay,NULL);
 }
 printf("# %d stable content changes in %.3f s = %.3f/s; largest gap %.3f ms\n",count,now()-start,count/(now()-start),maximum*1000);
 munmap(mem,fix.smem_len);close(fd);return 0;
}
