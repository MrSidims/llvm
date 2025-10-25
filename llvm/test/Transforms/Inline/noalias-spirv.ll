; Test that alias scope metadata does not include function names for SPIR-V targets.
; This reduces metadata bloat and improves compilation performance for SYCL/SPIR-V.
;
; RUN: opt -passes=inline -enable-noalias-to-md-conversion -S < %s | FileCheck %s

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spirv64-unknown-unknown"

define void @sycl_kernel(ptr noalias nocapture %a, ptr nocapture readonly %b) #0 {
entry:
  %0 = load i32, ptr %b, align 4
  %arrayidx = getelementptr inbounds i32, ptr %a, i64 10
  store i32 %0, ptr %arrayidx, align 4
  ret void
}

define spir_kernel void @kernel_caller(ptr addrspace(1) nocapture %a, ptr addrspace(1) nocapture readonly %b) #0 {
entry:
  %a.cast = addrspacecast ptr addrspace(1) %a to ptr
  %b.cast = addrspacecast ptr addrspace(1) %b to ptr
  tail call void @sycl_kernel(ptr %a.cast, ptr %b.cast)
  %0 = load i32, ptr %b.cast, align 4
  %arrayidx = getelementptr inbounds i32, ptr %a.cast, i64 15
  store i32 %0, ptr %arrayidx, align 4
  ret void
}

; CHECK-LABEL: define spir_kernel void @kernel_caller(ptr addrspace(1) captures(none) %a, ptr addrspace(1) readonly captures(none) %b) #0 {
; CHECK: entry:
; CHECK:   call void @llvm.experimental.noalias.scope.decl
; CHECK:   [[TMP0:%.+]] = load i32, ptr %b.cast, align 4
; CHECK:   %arrayidx.i = getelementptr inbounds i32, ptr %a.cast, i64 10
; CHECK:   store i32 [[TMP0]], ptr %arrayidx.i, align 4
; CHECK:   [[TMP1:%.+]] = load i32, ptr %b.cast, align 4
; CHECK:   %arrayidx = getelementptr inbounds i32, ptr %a.cast, i64 15
; CHECK:   store i32 [[TMP1]], ptr %arrayidx, align 4
; CHECK:   ret void
; CHECK: }

; For SPIR-V targets, metadata should NOT contain function names
; Verify function name is NOT present in the metadata
; CHECK-NOT: !"sycl_kernel"

attributes #0 = { nounwind }
