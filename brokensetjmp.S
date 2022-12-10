/* Compile with: gcc -m32 -shared -o libBrokenSetJmp.so brokensetjmp.S */
/* Use with: LD_PRELOAD=libBrokenSetJmp.so ./application */

#define JB_SP 4
#define JB_PC 5
#define JMPBUF 4
#define SIGMSK JMPBUF + 4

#define POINTER_GUARD 0x18

#define PTR_MANGLE(reg)  xorl %gs:POINTER_GUARD, reg; \
                         roll $9, reg;

#define RTLD_NOW $-1

.section .rodata.str, "aMS", @progbits, 1
setjmp_name:
    .string "setjmp"
_setjmp_name:
    .string "_setjmp"
__sigsetjmp_name:
    .string "__sigsetjmp"

.section .text, "ax", @progbits
.global _setjmp, setjmp, __sigsetjmp, _longjmp, longjmp, siglongjmp
_setjmp:
    call __x86.get_pc_thunk.dx
    addl $_GLOBAL_OFFSET_TABLE_, %edx
    movl _setjmp_real@GOT(%edx), %edx
    /* Call real glibc implementation */
    pushl JMPBUF(%esp)
    call *(%edx)
    jmp .update_with_unmangled

setjmp:
    call __x86.get_pc_thunk.dx
    addl $_GLOBAL_OFFSET_TABLE_, %edx
    movl setjmp_real@GOT(%edx), %edx
    /* Call real glibc implementation */
    pushl JMPBUF(%esp)
    call *(%edx)
    jmp .update_with_unmangled

__sigsetjmp:
    call __x86.get_pc_thunk.dx
    addl $_GLOBAL_OFFSET_TABLE_, %edx
    movl __sigsetjmp_real@GOT(%edx), %edx
    /* Call real glibc implementation */
    pushl SIGMSK(%esp)
    pushl SIGMSK(%esp)
    call *(%edx)
    popl %edx /* Two args pushed, pop one back here */
    jmp .update_with_unmangled

.update_with_unmangled:
    /* Restore stack after call of real glibc implementation*/
    popl %edx
    /* After return jmp_buf will be filled with mangled SP and PC pointing to us */
    movl JMPBUF(%esp), %edx
    /* Put unmangled caller's SP */
    leal JMPBUF(%esp), %ecx
    movl %ecx, (JB_SP*4)(%edx)
    /* Put unamangled caller's PC */
    movl 0(%esp), %ecx
    movl %ecx, (JB_PC*4)(%edx)
    ret

_longjmp:
longjmp:
siglongjmp:
    /* Load jmp_buf */
    movl JMPBUF(%esp), %edx
    /* Mangle SP */
    movl (JB_SP*4)(%edx), %ecx
    PTR_MANGLE(%ecx)
    movl %ecx, (JB_SP*4)(%edx)
    /* Mangle PC */
    movl (JB_PC*4)(%edx), %ecx
    PTR_MANGLE(%ecx)
    movl %ecx, (JB_PC*4)(%edx)
    /* Jump to glibc implementation */
    call __x86.get_pc_thunk.dx
    addl $_GLOBAL_OFFSET_TABLE_, %edx
    movl %edx, %ebx /* No need to save/restore %ebx, as we're doing longjmp anyway */
    jmp __libc_siglongjmp@PLT

get_real_funcs:
    call __x86.get_pc_thunk.dx
    addl $_GLOBAL_OFFSET_TABLE_, %edx
    pushl %ebx
    movl %edx, %ebx

    leal setjmp_name@GOTOFF(%ebx), %eax
    pushl %eax
    pushl RTLD_NOW
    call dlsym@PLT
    movl %eax, setjmp_real@GOTOFF(%ebx)
    addl $0x8, %esp

    leal _setjmp_name@GOTOFF(%ebx), %eax
    pushl %eax
    pushl RTLD_NOW
    call dlsym@PLT
    movl %eax, _setjmp_real@GOTOFF(%ebx)
    addl $0x8, %esp

    leal __sigsetjmp_name@GOTOFF(%ebx), %eax
    pushl %eax
    pushl RTLD_NOW
    call dlsym@PLT
    movl %eax, __sigsetjmp_real@GOTOFF(%ebx)
    addl $0x8, %esp

    popl %ebx
    ret

.section .init_array, "aw"
.align 4
    .long get_real_funcs

.section .text.__x86.get_pc_thunk.dx, "axG", @progbits, __x86.get_pc_thunk.dx, comdat
.globl __x86.get_pc_thunk.dx
.hidden __x86.get_pc_thunk.dx
__x86.get_pc_thunk.dx:
    movl (%esp), %edx
    ret

.local setjmp_real, _setjmp_real, __sigsetjmp_real
.comm setjmp_real, 4, 4
.comm _setjmp_real, 4, 4
.comm __sigsetjmp_real, 4, 4
