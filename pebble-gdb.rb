class PebbleGdb < Formula
  desc "GNU debugger customized for Pebble"
  homepage "https://www.gnu.org/software/gdb/"
  url "https://ftpmirror.gnu.org/gdb/gdb-7.12.tar.xz"
  mirror "https://ftp.gnu.org/gnu/gdb/gdb-7.12.tar.xz"
  sha256 "834ff3c5948b30718343ea57b11cbc3235d7995c6a4f3a5cecec8c8114164f94"
  version "7.12-pebble1"

  bottle do
    root_url "http://pebble-homebrew.s3.amazonaws.com"
    sha256 "ebc1f0c26473a499e27db00211fef83cedb9d593c828aa5bf2d56728b14e8913" => :el_capitan
    sha256 "acc158191ef8f3960dc913a71510d4b18ac757da2d8b9f389afaf27982cee078" => :sierra
  end

  option "without-python", "Use the system Python; by default the Homebrew version of Python is used"

  depends_on "pkg-config" => :build
  depends_on "python" => :recommended
  depends_on "guile" => :optional
  # Prefer the homebrew-dupes libiconv as it fixes an infinite-loop bug in the
  # Apple-supplied version (PBL-17248).
  depends_on "libiconv" => :recommended

  # Patch the frame-unwinder so that it can unwind past exceptions (PBL-43127).
  # This patch is based on the patch in https://bugs.launchpad.net/gcc-arm-embedded/+bug/1566054
  patch :DATA

  def install
    args = [
      "--prefix=#{prefix}",
      "--disable-debug",
      "--disable-dependency-tracking",
      "--disable-nls",
      "--disable-sim",
      "--disable-gas",
      "--disable-binutils",
      "--disable-ld",
      "--disable-gprof",
      "--target=arm-none-eabi",
      "--program-prefix=pebble-",
      "--with-pkgversion=GDB for Pebble Firmware",
    ]

    args << "--with-guile" if build.with? "guile"

    if build.with? "python"
      args << "--with-python=#{HOMEBREW_PREFIX}"
    else
      args << "--with-python=/usr"
    end

    inreplace "gdb/version.in", /^.*$/, version.to_s
    system "./configure", *args
    system "make"
    system "make", "install"

    # Remove conflicting items with binutils
    rm_rf include
    rm_rf lib
    rm_rf share/"locale"
    rm_rf share/"info"
  end

  test do
    system bin/"pebble-gdb", bin/"pebble-gdb", "-configuration"
  end
end

__END__
diff --git a/gdb/arm-tdep.c b/gdb/arm-tdep.c
index 2525bd8..5ded392 100644
--- a/gdb/arm-tdep.c
+++ b/gdb/arm-tdep.c
@@ -2959,13 +2959,38 @@ arm_m_exception_cache (struct frame_info *this_frame)
   enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
   struct arm_prologue_cache *cache;
   CORE_ADDR unwound_sp;
+  CORE_ADDR this_lr;
   LONGEST xpsr;
+  int main_stack_used;
+  int extended_frame_type;
+  int stack_regnum;
 
   cache = FRAME_OBSTACK_ZALLOC (struct arm_prologue_cache);
   cache->saved_regs = trad_frame_alloc_saved_regs (this_frame);
 
-  unwound_sp = get_frame_register_unsigned (this_frame,
-					    ARM_SP_REGNUM);
+  /* We need LR to know: 1- if the FPU was used, 2- which stack was used.
+     "B1.5.6 Exception entry behavior" in ARMv7-M Architecture Reference
+     Manual Issue D (or the last one) gives the various bits in LR
+     involved in this. NOTE: this LR is different of the stacked one.  */
+  this_lr = get_frame_register_unsigned (this_frame, ARM_LR_REGNUM);
+  main_stack_used = (this_lr & 0xf) != 0xd;
+  extended_frame_type = (this_lr & (1 << 4)) == 0;
+  if (main_stack_used)
+    stack_regnum = ARM_SP_REGNUM;
+  else
+    {
+      /* PSP is the banked process stack pointer register, which the target
+         debug stub may not have available.  */
+      stack_regnum = user_reg_map_name_to_regnum (gdbarch, "psp", -1);
+      if (stack_regnum == -1)
+        {
+          /* Fall back to old behaviour.  */
+          warning (_("Can't get psp register; backtrace may be incomplete"));
+          stack_regnum = ARM_SP_REGNUM;
+        }
+    }
+
+  unwound_sp = get_frame_register_unsigned (this_frame, stack_regnum);
 
   /* The hardware saves eight 32-bit words, comprising xPSR,
      ReturnAddress, LR (R14), R12, R3, R2, R1, R0.  See details in
@@ -2980,10 +3005,47 @@ arm_m_exception_cache (struct frame_info *this_frame)
   cache->saved_regs[15].addr = unwound_sp + 24;
   cache->saved_regs[ARM_PS_REGNUM].addr = unwound_sp + 28;
 
+  if (extended_frame_type)
+    {
+      int s0_offset;
+      int fpscr_offset;
+
+      s0_offset = user_reg_map_name_to_regnum (gdbarch, "s0", -1);
+      fpscr_offset = user_reg_map_name_to_regnum (gdbarch, "fpscr", -1);
+
+      if (s0_offset == -1 || fpscr_offset == -1)
+	{
+	  /* Ooops. */
+	  warning (_("can't get register offsets in cache; "
+		     "fpu info may be wrong"));
+	}
+      else
+	{
+	  int i;
+	  int fpu_reg_offset;
+
+	  fpu_reg_offset = unwound_sp + 0x20;
+
+	  /* XXX: This doesn't take into account the lazy stacking, see "Lazy
+	     context save of FP state", in B1.5.7.  */
+	  for (i = 0; i < 16; ++i, fpu_reg_offset += 4)
+	    {
+	      cache->saved_regs[s0_offset + i].addr = fpu_reg_offset;
+	    }
+	  cache->saved_regs[fpscr_offset].addr = unwound_sp + 0x60;
+	}
+
+	/* Offset 0x64 is reserved */
+	cache->prev_sp = unwound_sp + 0x68;
+    }
+  else
+    {
+      cache->prev_sp = unwound_sp + 32;
+    }
+
   /* If bit 9 of the saved xPSR is set, then there is a four-byte
      aligner between the top of the 32-byte stack frame and the
      previous context's stack pointer.  */
-  cache->prev_sp = unwound_sp + 32;
   if (safe_read_memory_integer (unwound_sp + 28, 4, byte_order, &xpsr)
       && (xpsr & (1 << 9)) != 0)
     cache->prev_sp += 4;
