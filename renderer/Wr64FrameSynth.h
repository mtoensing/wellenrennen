// SPDX-License-Identifier: GPL-2.0-only
// Experimental GLES image-space frame synthesis for the WR64 PortMaster port.
// Runs exclusively on GLideN64's GL worker. No simulation timing changes.
#pragma once
#include <chrono>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>
#include <vector>

namespace wr64_synth {
using Clock = std::chrono::steady_clock;
inline double now() { return std::chrono::duration<double>(Clock::now().time_since_epoch()).count(); }
inline bool enabled() { static const bool e = [] { const char* value=std::getenv("WR64_FRAME_SYNTH");return value && std::strcmp(value,"1")==0; }(); return e; }

// GLideN64 caches GL state on its producer thread. Preserve every state changed
// here so its cache and the driver stay in agreement when normal work resumes.
struct State {
    GLint program, vao, drawFbo, readFbo, active, viewport[4], textures[3];
    GLint blend, depth, cull, scissor;
    using IsEnabledIndexed=GLboolean(*)(GLenum,GLuint);
    static IsEnabledIndexed indexed() {
        static auto fn=reinterpret_cast<IsEnabledIndexed>(::CoreVideo_GL_GetProcAddress("glIsEnabledi"));
        return fn;
    }
    static void disableBlend() {
        if(ptrDisablei && indexed())ptrDisablei(GL_BLEND,0);else ptrDisable(GL_BLEND);
    }
    State() {
        ptrGetIntegerv(GL_CURRENT_PROGRAM, &program);
        ptrGetIntegerv(GL_VERTEX_ARRAY_BINDING, &vao);
        ptrGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &drawFbo);
        ptrGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readFbo);
        ptrGetIntegerv(GL_ACTIVE_TEXTURE, &active);
        ptrGetIntegerv(GL_VIEWPORT, viewport);
        if(indexed() && ptrEnablei && ptrDisablei)blend=indexed()(GL_BLEND,0);
        else ptrGetIntegerv(GL_BLEND,&blend);
        ptrGetIntegerv(GL_DEPTH_TEST, &depth);
        ptrGetIntegerv(GL_CULL_FACE, &cull); ptrGetIntegerv(GL_SCISSOR_TEST, &scissor);
        for (int i=0;i<3;++i) {
            ptrActiveTexture(GL_TEXTURE0+i); ptrGetIntegerv(GL_TEXTURE_BINDING_2D,&textures[i]);
        }
    }
    ~State() {
        ptrUseProgram(program); ptrBindVertexArray(vao);
        ptrBindFramebuffer(GL_DRAW_FRAMEBUFFER, drawFbo);
        ptrBindFramebuffer(GL_READ_FRAMEBUFFER, readFbo);
        ptrViewport(viewport[0],viewport[1],viewport[2],viewport[3]);
        if(indexed() && ptrEnablei && ptrDisablei) {
            if(blend)ptrEnablei(GL_BLEND,0);else ptrDisablei(GL_BLEND,0);
        } else restore(GL_BLEND,blend);
        restore(GL_DEPTH_TEST,depth);
        restore(GL_CULL_FACE,cull); restore(GL_SCISSOR_TEST,scissor);
        for(int i=0;i<3;++i) { ptrActiveTexture(GL_TEXTURE0+i); ptrBindTexture(GL_TEXTURE_2D,textures[i]); }
        ptrActiveTexture(active);
    }
    static void restore(GLenum c, GLint value) { if(value) ptrEnable(c); else ptrDisable(c); }
};

constexpr const char* vertex = R"GLSL(#version 300 es
precision highp float;
out vec2 uv;
void main() {
    vec2 p=vec2(float((gl_VertexID<<1)&2),float(gl_VertexID&2));
    uv=p; gl_Position=vec4(p*2.0-1.0,0.0,1.0);
}
)GLSL";
// Block matching is done at 40x30. A 4-tap patch reduces accidental matches
// in water/noise; a displacement penalty keeps unmoving HUD elements still.
constexpr const char* opticalFlow = R"GLSL(#version 300 es
precision highp float;
in vec2 uv;
layout(location=0) out vec4 result;
uniform sampler2D oldFrame, newFrame;
uniform vec2 grid;
float cost(vec2 d) {
    float e=0.0;
    for(int j=0;j<2;++j) for(int i=0;i<2;++i) {
        vec2 p=(vec2(float(i),float(j))-.5)*1.4/grid;
        vec3 a=texture(newFrame,uv+p).rgb;
        vec3 b=texture(oldFrame,uv+p+d).rgb;
        vec3 x=a-b; e+=dot(x,x);
    }
    return e+dot(d*grid,d*grid)*0.0003;
}
void main() {
    vec2 best=vec2(0.0); float err=cost(best);
    for(int y=-2;y<=2;++y) for(int x=-2;x<=2;++x) {
        vec2 d=vec2(float(x),float(y))/grid;
        float e=cost(d); if(e<err) {err=e;best=d;}
    }
    vec2 center=best;
    for(int y=-1;y<=1;++y) for(int x=-1;x<=1;++x) {
        vec2 d=center+vec2(float(x),float(y))*.5/grid;
        float e=cost(d); if(e<err) {err=e;best=d;}
    }
    center=best;
    for(int y=-1;y<=1;++y) for(int x=-1;x<=1;++x) {
        vec2 d=center+vec2(float(x),float(y))*.25/grid;
        float e=cost(d); if(e<err) {err=e;best=d;}
    }
    // Reject poorly matched blocks rather than inventing large movements.
    float confidence=1.0-smoothstep(.04,.25,err);
    result=vec4(best*8.0+128.0/255.0,confidence,1.0);
}
)GLSL";
// Small images keep block-matching reads in the texture cache.
constexpr const char* downsample = R"GLSL(#version 300 es
precision highp float;
in vec2 uv;layout(location=0) out vec4 result;
uniform sampler2D newFrame;
uniform vec2 sampleStep;
void main() {
    vec2 d=sampleStep;
    result=(texture(newFrame,uv+d)+texture(newFrame,uv-d)+
            texture(newFrame,uv+vec2(d.x,-d.y))+texture(newFrame,uv+vec2(-d.x,d.y)))*.25;
}
)GLSL";
constexpr const char* interpolate = R"GLSL(#version 300 es
precision highp float;
in vec2 uv;
layout(location=0) out vec4 result;
uniform sampler2D oldFrame,newFrame,flow;
uniform float phase;
void main() {
    const vec2 lo=vec2(16.5/640.0,38.5/480.0);
    const vec2 hi=vec2(623.5/640.0,441.5/480.0);
    vec4 stable=phase<.5 ? texture(oldFrame,uv) : texture(newFrame,uv);
    if(uv.y>.76 || uv.y<.12 || uv.x<lo.x || uv.x>hi.x) { result=stable;return; }
    // Color-guided upsampling keeps background flow out of the rider's edges.
    vec2 g=uv*vec2(40.0,30.0)-.5;
    vec2 base=floor(g),frac=fract(g);
    vec3 center=texture(newFrame,uv).rgb;
    vec3 f=vec3(0.0);float total=0.0;
    for(int y=0;y<2;++y) for(int x=0;x<2;++x) {
        vec2 cell=base+vec2(float(x),float(y));
        vec2 q=(cell+.5)/vec2(40.0,30.0);
        vec3 color=texture(newFrame,q).rgb;
        vec3 difference=color-center;
        float guide=1.0/(.01+dot(difference,difference)*8.0);
        vec2 bilinear=mix(vec2(1.0)-frac,frac,vec2(float(x),float(y)));
        float weight=bilinear.x*bilinear.y*guide;
        f+=texture(flow,q).rgb*weight;total+=weight;
    }
    f/=max(total,.00001);
    vec2 d=(f.xy-128.0/255.0)/8.0;
    vec4 a=texture(oldFrame,clamp(uv+phase*d,lo,hi));
    vec4 b=texture(newFrame,clamp(uv-(1.0-phase)*d,lo,hi));
    float mismatch=length(a.rgb-b.rgb);
    // Occlusions and ambiguous foam/limb matches fall back to a real frame.
    // Never blend two visibly different silhouettes into a double image.
    if(f.z<.6 || mismatch>.35)result=stable;
    else if(mismatch>.12)result=phase<.5 ? a : b;
    else result=mix(a,b,phase);
}
)GLSL";

constexpr const char* composite = R"GLSL(#version 300 es
precision highp float;
in vec2 uv;layout(location=0) out vec4 result;
uniform sampler2D oldFrame,newFrame,warpFrame;
uniform float phase;
void main() {
    if(uv.y>.76 || uv.y<.12 || uv.x<16.5/640.0 || uv.x>623.5/640.0)
        result=phase<.5 ? texture(oldFrame,uv) : texture(newFrame,uv);
    else result=texture(warpFrame,uv);
}
)GLSL";

inline GLuint shader(GLenum type,const char* source) {
    GLuint s=ptrCreateShader(type); ptrShaderSource(s,1,&source,nullptr); ptrCompileShader(s);
    GLint ok=0; ptrGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if(!ok) { char log[2048]; ptrGetShaderInfoLog(s,sizeof(log),nullptr,log); std::fprintf(stderr,"[frame-synth] shader: %s\n",log); ptrDeleteShader(s); return 0; }
    return s;
}
inline GLuint program(const char* fs) {
    GLuint v=shader(GL_VERTEX_SHADER,vertex),f=shader(GL_FRAGMENT_SHADER,fs);
    if(!v||!f) { if(v)ptrDeleteShader(v);if(f)ptrDeleteShader(f);return 0; }
    GLuint p=ptrCreateProgram();ptrAttachShader(p,v);ptrAttachShader(p,f);ptrLinkProgram(p);
    ptrDeleteShader(v);ptrDeleteShader(f);GLint ok=0;ptrGetProgramiv(p,GL_LINK_STATUS,&ok);
    if(!ok) {char log[2048];ptrGetProgramInfoLog(p,sizeof(log),nullptr,log);std::fprintf(stderr,"[frame-synth] link: %s\n",log);ptrDeleteProgram(p);return 0;}
    return p;
}
// Optional asynchronous GPU timers; unavailable extensions leave this inert.
struct Timer {
    using Gen=void(*)(GLsizei,GLuint*);using Begin=void(*)(GLenum,GLuint);
    using End=void(*)(GLenum);using Get=void(*)(GLuint,GLenum,GLuint*);
    using Get64=void(*)(GLuint,GLenum,GLuint64*);
    Gen gen=nullptr;Begin beginQuery=nullptr;End endQuery=nullptr;Get get=nullptr;Get64 get64=nullptr;
    GLuint ids[8]{};bool pending[8]{},active=false;unsigned index=0,count=0;double total=0,maximum=0;
    void init() {
        if(!std::getenv("WR64_SYNTH_PROFILE"))return;
        const char* ext=reinterpret_cast<const char*>(ptrGetString(GL_EXTENSIONS));
        if(!ext||!std::strstr(ext,"GL_EXT_disjoint_timer_query"))return;
        gen=reinterpret_cast<Gen>(::CoreVideo_GL_GetProcAddress("glGenQueriesEXT"));
        beginQuery=reinterpret_cast<Begin>(::CoreVideo_GL_GetProcAddress("glBeginQueryEXT"));
        endQuery=reinterpret_cast<End>(::CoreVideo_GL_GetProcAddress("glEndQueryEXT"));
        get=reinterpret_cast<Get>(::CoreVideo_GL_GetProcAddress("glGetQueryObjectuivEXT"));
        get64=reinterpret_cast<Get64>(::CoreVideo_GL_GetProcAddress("glGetQueryObjectui64vEXT"));
        if(gen&&beginQuery&&endQuery&&get&&get64)gen(8,ids);else gen=nullptr;
    }
    void begin() {
        if(!gen)return;
        if(pending[index]) {
            GLuint available=0;get(ids[index],0x8867,&available);
            if(!available)return;
            GLuint64 ns=0;get64(ids[index],0x8866,&ns);
            double ms=ns/1000000.0;total+=ms;maximum=std::max(maximum,ms);++count;
        }
        beginQuery(0x88BF,ids[index]);active=true;
    }
    void end() {
        if(active){endQuery(0x88BF);pending[index]=true;index=(index+1)%8;active=false;}
    }
    void report(const char* name) {
        if(gen)std::fprintf(stderr,"[frame-synth] GPU %s: mean %.3f ms max %.3f ms (%u samples)\n",name,count?total/count:0,maximum,count);
        total=maximum=0;count=0;
    }
};
struct Synth {
    GLuint color[2]{},small[2]{},motion=0,fbo=0,smallFbo[2]{},warpTexture=0,warpFbo=0,vao=0,flowProgram=0,presentProgram=0,copyProgram=0,compositeProgram=0;
    int current=0,width=640,height=480; bool ready=false,haveFrame=false,havePair=false,sceneBusy=false,dumped=false,active=true;
    double started=0,captured=0,period=.05,lastSwap=0,lastSubmit=0,nextPresent=0,report=0;
    unsigned native=0,shown=0,synthetic=0;double flowSeconds=0,maxGap=0;
    PFNGLCOPYTEXSUBIMAGE2DPROC copy=nullptr;
    Timer flowTimer,warpTimer,copyTimer;
    void beginFrame(int divider) {
        const bool next=divider>=3;
        if(next!=active) {
            active=next;haveFrame=havePair=false;captured=nextPresent=lastSwap=0;
            native=shown=synthetic=0;flowSeconds=maxGap=0;report=now();
            std::fprintf(stderr,"[frame-synth] %s for native divider %d (UI at 30+ Hz remains native)\n",active?"enabled":"disabled",divider);
        }
        sceneBusy=active;
    }
    void texture(GLuint t,int w,int h) {
        ptrActiveTexture(GL_TEXTURE0);ptrBindTexture(GL_TEXTURE_2D,t);
        ptrTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,nullptr);
        ptrTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
        ptrTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        ptrTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
        ptrTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
    }
    bool init() {
        copy=reinterpret_cast<PFNGLCOPYTEXSUBIMAGE2DPROC>(::CoreVideo_GL_GetProcAddress("glCopyTexSubImage2D"));
        flowProgram=program(opticalFlow);presentProgram=program(interpolate);copyProgram=program(downsample);compositeProgram=program(composite);
        if(!copy||!flowProgram||!presentProgram||!copyProgram||!compositeProgram) return false;
        ptrGenTextures(2,color);ptrGenTextures(2,small);ptrGenTextures(1,&motion);ptrGenTextures(1,&warpTexture);ptrGenFramebuffers(1,&fbo);ptrGenFramebuffers(2,smallFbo);ptrGenFramebuffers(1,&warpFbo);ptrGenVertexArrays(1,&vao);
        texture(small[0],80,60);texture(small[1],80,60);texture(color[0],width,height);texture(color[1],width,height);texture(motion,40,30);texture(warpTexture,320,240);
        ptrBindFramebuffer(GL_FRAMEBUFFER,warpFbo);
        ptrFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,warpTexture,0);
        if(ptrCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)return false;
        for(int i=0;i<2;++i) {
            ptrBindFramebuffer(GL_FRAMEBUFFER,smallFbo[i]);
            ptrFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,small[i],0);
            if(ptrCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)return false;
        }
        ptrBindFramebuffer(GL_FRAMEBUFFER,fbo);ptrFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,motion,0);
        if(ptrCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)return false;
        for(GLuint p:{flowProgram,presentProgram,copyProgram,compositeProgram}) {
            ptrUseProgram(p);ptrUniform1i(ptrGetUniformLocation(p,"oldFrame"),0);
            ptrUniform1i(ptrGetUniformLocation(p,"newFrame"),1);
        }
        ptrUseProgram(compositeProgram);ptrUniform1i(ptrGetUniformLocation(compositeProgram,"warpFrame"),2);
        ptrUseProgram(copyProgram);ptrUniform2f(ptrGetUniformLocation(copyProgram,"sampleStep"),2.0f/640,2.0f/480);
        ptrUseProgram(presentProgram);ptrUniform1i(ptrGetUniformLocation(presentProgram,"flow"),2);
        ptrUseProgram(flowProgram);ptrUniform2f(ptrGetUniformLocation(flowProgram,"grid"),40,30);
        flowTimer.init();warpTimer.init();copyTimer.init();
        ready=true;started=report=now();std::fprintf(stderr,"[frame-synth] GLES optical flow 40x30 -> 640x480; original simulation unchanged\n");
        return true;
    }
    void setup() {
        ptrBindVertexArray(vao);State::disableBlend();ptrDisable(GL_DEPTH_TEST);ptrDisable(GL_CULL_FACE);ptrDisable(GL_SCISSOR_TEST);
        ptrActiveTexture(GL_TEXTURE0);ptrBindTexture(GL_TEXTURE_2D,color[1-current]);
        ptrActiveTexture(GL_TEXTURE1);ptrBindTexture(GL_TEXTURE_2D,color[current]);
        ptrActiveTexture(GL_TEXTURE2);ptrBindTexture(GL_TEXTURE_2D,motion);
    }
    void draw(double t) {
        setup();
        // The game itself renders at 320x240. Synthesize scene pixels there,
        // then scale to the panel; composite the original 640x480 HUD last.
        ptrBindFramebuffer(GL_FRAMEBUFFER,warpFbo);ptrViewport(0,0,320,240);
        ptrUseProgram(presentProgram);ptrUniform1f(ptrGetUniformLocation(presentProgram,"phase"),float(t));
        ptrDrawArrays(GL_TRIANGLES,0,3);
        ptrBindFramebuffer(GL_FRAMEBUFFER,0);ptrViewport(0,0,width,height);
        ptrActiveTexture(GL_TEXTURE2);ptrBindTexture(GL_TEXTURE_2D,warpTexture);
        ptrUseProgram(compositeProgram);ptrUniform1f(ptrGetUniformLocation(compositeProgram,"phase"),float(t));
        ptrDrawArrays(GL_TRIANGLES,0,3);
    }
    void present(double t,bool isSynthetic) {
        const double start=now();lastSubmit=start;
        if(!nextPresent)nextPresent=start;
        do { nextPresent+=1.0/60.0; } while(nextPresent<=start);
        warpTimer.begin();draw(t);warpTimer.end();
        ::CoreVideo_GL_SwapBuffers();
        const double end=now();
        // fbdev EGL may block until scanout even with swap interval zero.
        // Leave a real work window after a blocking swap; otherwise the timer
        // immediately swaps again and starves the native GL command stream.
        if(end-start>.004)nextPresent=end+.013;
        if(lastSwap)maxGap=std::max(maxGap,end-lastSwap);lastSwap=end;
        ++shown;if(isSynthetic)++synthetic;
        if(end-report>=5) {
            double secs=end-report;
            std::fprintf(stderr,"[frame-synth] native %.2f/s, swaps %.2f/s, synthetic %.2f/s, max gap %.2f ms, flow CPU %.2f ms/native, last swap %.2f ms\n",native/secs,shown/secs,synthetic/secs,maxGap*1000,native?flowSeconds*1000/native:0,(end-start)*1000);
            flowTimer.report("flow");warpTimer.report("warp");copyTimer.report("copy");
            native=shown=synthetic=0;flowSeconds=maxGap=0;report=end;
        }
    }
    bool swap() {
        if(!enabled()||!active)return false;
        State saved;
        if(!ready && !init())return false;
        const double time=now();if(haveFrame)period=std::max(.016,std::min(.1,time-captured));
        havePair=haveFrame;current=1-current;
        // Capture the fully composed native frame before the real swap.
        ptrBindFramebuffer(GL_READ_FRAMEBUFFER,0);ptrActiveTexture(GL_TEXTURE0);ptrBindTexture(GL_TEXTURE_2D,color[current]);
        copyTimer.begin();copy(GL_TEXTURE_2D,0,0,0,0,0,width,height);copyTimer.end();
        if(!haveFrame) {
            ptrBindTexture(GL_TEXTURE_2D,color[1-current]);copy(GL_TEXTURE_2D,0,0,0,0,0,width,height);
        }
        setup();
        const double flowStart=now();
        static unsigned checkedFrames=0;
        const bool check=checkedFrames++<3;
        if(check)std::fprintf(stderr,"[frame-synth] before lowpass error=0x%x\n",ptrGetError());
        flowTimer.begin();
        ptrBindFramebuffer(GL_FRAMEBUFFER,smallFbo[current]);
        ptrViewport(0,0,80,60);ptrUseProgram(copyProgram);ptrDrawArrays(GL_TRIANGLES,0,3);
        if(check)std::fprintf(stderr,"[frame-synth] lowpass error=0x%x fbo=0x%x\n",ptrGetError(),ptrCheckFramebufferStatus(GL_FRAMEBUFFER));
        if(!havePair) {
            ptrBindFramebuffer(GL_FRAMEBUFFER,smallFbo[1-current]);
            ptrDrawArrays(GL_TRIANGLES,0,3);
        }
        ptrActiveTexture(GL_TEXTURE0);ptrBindTexture(GL_TEXTURE_2D,small[1-current]);
        ptrActiveTexture(GL_TEXTURE1);ptrBindTexture(GL_TEXTURE_2D,small[current]);
        ptrBindFramebuffer(GL_FRAMEBUFFER,fbo);
        ptrViewport(0,0,40,30);ptrUseProgram(flowProgram);
        ptrDrawArrays(GL_TRIANGLES,0,3);flowTimer.end();
        if(check)std::fprintf(stderr,"[frame-synth] flow error=0x%x fbo=0x%x\n",ptrGetError(),ptrCheckFramebufferStatus(GL_FRAMEBUFFER));
        ptrActiveTexture(GL_TEXTURE0);ptrBindTexture(GL_TEXTURE_2D,color[1-current]);
        ptrActiveTexture(GL_TEXTURE1);ptrBindTexture(GL_TEXTURE_2D,color[current]);
        flowSeconds+=now()-flowStart;
        if(std::getenv("WR64_SYNTH_DUMP") && !dumped && now()-started>=std::max(2,std::atoi(std::getenv("WR64_SYNTH_DUMP")))) {
            dumped=true;
            const auto dump=[&](const char* name,GLuint tex,int w,int h) {
                // Read through a full-size default target: this driver reports
                // OOM when directly reading the small offscreen attachments.
                ptrBindFramebuffer(GL_FRAMEBUFFER,0);ptrViewport(0,0,width,height);
                ptrActiveTexture(GL_TEXTURE1);ptrBindTexture(GL_TEXTURE_2D,tex);
                ptrUseProgram(copyProgram);ptrUniform1i(ptrGetUniformLocation(copyProgram,"newFrame"),1);
                ptrUniform2f(ptrGetUniformLocation(copyProgram,"sampleStep"),0,0);
                ptrDrawArrays(GL_TRIANGLES,0,3);
                std::vector<unsigned char> pixels(size_t(width)*height*4);
                ptrReadPixels(0,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,pixels.data());
                if(FILE* out=std::fopen(name,"wb")){std::fwrite(pixels.data(),1,pixels.size(),out);std::fclose(out);}
                std::fprintf(stderr,"[frame-synth] dump %s source=%dx%d via 640x480 error=0x%x\n",name,w,h,ptrGetError());
            };
            dump("/tmp/wr64-motion.rgba",motion,40,30);
            dump("/tmp/wr64-small.rgba",small[current],80,60);
            dump("/tmp/wr64-current.rgba",color[current],width,height);
            dump("/tmp/wr64-previous.rgba",color[1-current],width,height);
            ptrUseProgram(copyProgram);ptrUniform2f(ptrGetUniformLocation(copyProgram,"sampleStep"),2.0f/640,2.0f/480);
            ptrBindFramebuffer(GL_FRAMEBUFFER,0);
            setup();
            for(int i=1;i<=3;++i) {
                draw(double(i)/3);
                std::vector<unsigned char> pixels(size_t(width)*height*4);
                ptrReadPixels(0,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,pixels.data());
                char name[64];std::snprintf(name,sizeof(name),"/tmp/wr64-phase-%d.rgba",i);
                if(FILE* out=std::fopen(name,"wb")){std::fwrite(pixels.data(),1,pixels.size(),out);std::fclose(out);}
            }
        }
        captured=now();haveFrame=true;++native;
        sceneBusy=false;
        if(now()>=nextPresent)present(0,false);
        return true;
    }
    void tick() {
        if(!enabled()||!active||!ready||!havePair)return;
        const double time=now();
        if(time<nextPresent)return;
        // Do not overwrite a native frame while its final default-buffer blit
        // is being assembled. Offscreen scene work can be interrupted safely.
        GLint target=0;ptrGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,&target);
        if(sceneBusy && target==0)return;
        State saved;setup();present(std::max(0.0,std::min(1.0,(time-captured)/period)),true);
    }
};
inline Synth& instance() { static Synth s;return s; }
} // namespace wr64_synth
inline bool wr64_synth_swap() { return wr64_synth::instance().swap(); }
inline void wr64_synth_tick() { wr64_synth::instance().tick(); }
inline void wr64_synth_begin(int divider) { wr64_synth::instance().beginFrame(divider); }
