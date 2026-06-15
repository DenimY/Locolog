#!/usr/bin/env python3
"""
xcodegen 실행 후 pbxproj 패치 스크립트
- Sparkle를 iOS 타겟에서 제거 (Sparkle는 macOS 전용)
- WidgetKit embed을 iOS 전용으로 제한
"""
import re
import subprocess
import sys

pbxproj_path = 'Locolog.xcodeproj/project.pbxproj'

with open(pbxproj_path, 'r') as f:
    content = f.read()

# ──────────────────────────────────────────────
# 1. WidgetKit embed platformFilter = ios 패치
# ──────────────────────────────────────────────
content = re.sub(
    r'(LocologWidget\.appex in Embed Foundation Extensions.*?settings = \{)',
    r'platformFilter = ios; \1',
    content
)

# ──────────────────────────────────────────────
# 2. Sparkle를 iOS 타겟에서 완전히 제거
# ──────────────────────────────────────────────

# Step 2-1. iOS 타겟의 packageProductDependencies에서 Sparkle UUID 찾기
ios_target_match = re.search(
    r'/\* Locolog_iOS \*/ = \{.*?packageProductDependencies = \(([^)]*)\)',
    content, re.DOTALL
)
if not ios_target_match:
    print("⚠️  Locolog_iOS 타겟을 찾지 못했습니다.")
    sys.exit(1)

ios_deps_str = ios_target_match.group(1)

# 모든 Sparkle XCSwiftPackageProductDependency UUID 수집
all_sparkle_uuids = re.findall(
    r'(\w+) /\* Sparkle \*/ = \{\s*isa = XCSwiftPackageProductDependency;',
    content
)

# iOS 타겟 deps 안에 있는 UUID만 필터링
ios_sparkle_uuids = [uid for uid in all_sparkle_uuids if uid in ios_deps_str]

if not ios_sparkle_uuids:
    print("ℹ️  iOS 타겟에 Sparkle 참조가 없습니다. (이미 제거됨)")
else:
    for uid in ios_sparkle_uuids:
        # PBXBuildFile UUID 찾기 (productRef = uid)
        bf_match = re.search(
            r'(\w+) /\* Sparkle in Frameworks \*/ = \{[^}]*productRef = ' + uid + r'[^}]*\};',
            content
        )
        if bf_match:
            bf_uuid = bf_match.group(1)
            # PBXBuildFile 항목 제거
            content = re.sub(
                r'\s*' + bf_uuid + r' /\* Sparkle in Frameworks \*/ = \{[^}]*\};\n',
                '\n', content
            )
            # Frameworks 빌드 페이즈에서 참조 제거
            content = re.sub(
                r'\t+' + bf_uuid + r' /\* Sparkle in Frameworks \*/,\n',
                '', content
            )

        # iOS 타겟 packageProductDependencies에서 제거
        content = re.sub(
            r'\t+' + uid + r' /\* Sparkle \*/,\n',
            '', content
        )

        # XCSwiftPackageProductDependency 정의 항목 제거
        content = re.sub(
            r'\s*' + uid + r' /\* Sparkle \*/ = \{[^}]*\};\n',
            '\n', content
        )

    print(f"✅ Sparkle를 iOS 타겟에서 제거했습니다. (UUID: {ios_sparkle_uuids})")

# ──────────────────────────────────────────────
# 3. Sparkle PBXBuildFile의 platformFilter = maccatalyst 제거
#    (xcodegen이 platformFilter: macOS → maccatalyst로 잘못 매핑하는 버그 수정)
#    iOS BuildFile은 이미 제거했으므로 남은 항목은 macOS 전용
#    → platformFilter 제거 시 native macOS 빌드에서 정상 링크됨
# ──────────────────────────────────────────────
content = re.sub(
    r'(isa = PBXBuildFile; )platformFilter = maccatalyst; (productRef = \w+ /\* Sparkle \*/)',
    r'\1\2',
    content
)
print("✅ Sparkle PBXBuildFile platformFilter 교정 완료")

with open(pbxproj_path, 'w') as f:
    f.write(content)

print("✅ pbxproj 패치 완료")
