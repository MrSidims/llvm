; Test that alias scope metadata does not include function names for SPIR targets.
; This reduces metadata bloat and improves compilation performance for SYCL/SPIR-V.
;
; RUN: opt -passes=inline -enable-noalias-to-md-conversion -S < %s | FileCheck %s

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir64-unknown-unknown"

define void @callee(ptr noalias nocapture %a, ptr nocapture readonly %c) #0 {
entry:
  %0 = load float, ptr %c, align 4
  %arrayidx = getelementptr inbounds float, ptr %a, i64 5
  store float %0, ptr %arrayidx, align 4
  ret void
}

define void @caller(ptr nocapture %a, ptr nocapture readonly %c) #0 {
entry:
  tail call void @callee(ptr %a, ptr %c)
  %0 = load float, ptr %c, align 4
  %arrayidx = getelementptr inbounds float, ptr %a, i64 7
  store float %0, ptr %arrayidx, align 4
  ret void
}

; CHECK-LABEL: define void @caller(ptr captures(none) %a, ptr readonly captures(none) %c) #0 {
; CHECK: entry:
; CHECK:   call void @llvm.experimental.noalias.scope.decl
; CHECK:   [[TMP0:%.+]] = load float, ptr %c, align 4, !noalias ![[NOALIAS:[0-9]+]]
; CHECK:   %arrayidx.i = getelementptr inbounds float, ptr %a, i64 5
; CHECK:   store float [[TMP0]], ptr %arrayidx.i, align 4, !alias.scope ![[SCOPE:[0-9]+]]
; CHECK:   [[TMP1:%.+]] = load float, ptr %c, align 4
; CHECK:   %arrayidx = getelementptr inbounds float, ptr %a, i64 7
; CHECK:   store float [[TMP1]], ptr %arrayidx, align 4
; CHECK:   ret void
; CHECK: }

; For SPIR targets, metadata should NOT contain function names
; CHECK: ![[SCOPE]] = !{![[SCOPE_MD:[0-9]+]]}
; CHECK: ![[SCOPE_MD]] = distinct !{![[SCOPE_MD]], ![[DOMAIN:[0-9]+]]}
; CHECK: ![[DOMAIN]] = distinct !{![[DOMAIN]]}

; Verify function name is NOT present in the metadata
; CHECK-NOT: !"callee"

define void @callee2(ptr noalias nocapture %a, ptr noalias nocapture %b, ptr nocapture readonly %c) #0 {
entry:
  %0 = load float, ptr %c, align 4
  %arrayidx = getelementptr inbounds float, ptr %a, i64 5
  store float %0, ptr %arrayidx, align 4
  %arrayidx1 = getelementptr inbounds float, ptr %b, i64 8
  store float %0, ptr %arrayidx1, align 4
  ret void
}

define void @caller2(ptr nocapture %a, ptr nocapture %b, ptr nocapture readonly %c) #0 {
entry:
  tail call void @callee2(ptr %a, ptr %b, ptr %c)
  %0 = load float, ptr %c, align 4
  %arrayidx = getelementptr inbounds float, ptr %a, i64 7
  store float %0, ptr %arrayidx, align 4
  ret void
}

; CHECK-LABEL: define void @caller2(ptr captures(none) %a, ptr captures(none) %b, ptr readonly captures(none) %c) #0 {
; CHECK: entry:
; CHECK:   call void @llvm.experimental.noalias.scope.decl
; CHECK:   call void @llvm.experimental.noalias.scope.decl
; CHECK:   [[TMP0:%.+]] = load float, ptr %c, align 4
; CHECK:   %arrayidx.i = getelementptr inbounds float, ptr %a, i64 5
; CHECK:   store float [[TMP0]], ptr %arrayidx.i, align 4
; CHECK:   %arrayidx1.i = getelementptr inbounds float, ptr %b, i64 8
; CHECK:   store float [[TMP0]], ptr %arrayidx1.i, align 4
; CHECK:   [[TMP1:%.+]] = load float, ptr %c, align 4
; CHECK:   %arrayidx = getelementptr inbounds float, ptr %a, i64 7
; CHECK:   store float [[TMP1]], ptr %arrayidx, align 4
; CHECK:   ret void
; CHECK: }

; Verify function names and argument names are NOT present in the metadata
; CHECK-NOT: !"callee2"
; CHECK-NOT: !"%a"
; CHECK-NOT: !"%b"

attributes #0 = { nounwind }
