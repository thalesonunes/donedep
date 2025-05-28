#!/bin/bash

# DoneDep Advanced Health Check Script
# Author: Thales Nunes
# Date: 28/05/2025
# Version: 3.0 - Enhanced with deep analysis and performance monitoring

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Status counters
CHECKS_TOTAL=0
CHECKS_PASSED=0
WARNINGS=0
ERRORS=0
PERFORMANCE_ISSUES=0

# Global variables for analysis
START_TIME=$(date +%s)
TEMP_DIR="/tmp/donedep_verify_$$"

# Function to print status
print_status() {
    local status=$1
    local message=$2
    local details=${3:-""}
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    
    case $status in
        "pass")
            echo -e "${GREEN}✓${NC} $message"
            [ -n "$details" ] && echo -e "  ${GRAY}$details${NC}"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            ;;
        "warn")
            echo -e "${YELLOW}⚠${NC} $message"
            [ -n "$details" ] && echo -e "  ${GRAY}$details${NC}"
            WARNINGS=$((WARNINGS + 1))
            ;;
        "fail")
            echo -e "${RED}✗${NC} $message"
            [ -n "$details" ] && echo -e "  ${GRAY}$details${NC}"
            ERRORS=$((ERRORS + 1))
            ;;
        "info")
            echo -e "${BLUE}ℹ${NC} $message"
            [ -n "$details" ] && echo -e "  ${GRAY}$details${NC}"
            ;;
        "perf")
            echo -e "${PURPLE}⚡${NC} $message"
            [ -n "$details" ] && echo -e "  ${GRAY}$details${NC}"
            PERFORMANCE_ISSUES=$((PERFORMANCE_ISSUES + 1))
            ;;
    esac
}

# Function to print section header with timing
print_header() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    echo -e "\n${CYAN}[$elapsed s] $1${NC}"
    echo "$(echo "$1" | sed 's/./=/g')"
}

# Function to check file size and performance
check_file_performance() {
    local file=$1
    local max_size_mb=${2:-10}
    
    if [ -f "$file" ]; then
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        local size_mb=$((size / 1024 / 1024))
        
        if [ "$size_mb" -gt "$max_size_mb" ]; then
            print_status "perf" "Large file detected: $(basename "$file") (${size_mb}MB)" "Consider archiving or splitting large data files"
            return 1
        fi
    fi
    return 0
}

# Function to validate JSON structure
validate_json_structure() {
    local file=$1
    local expected_structure=$2
    
    if [ -f "$file" ] && command -v jq &> /dev/null; then
        case $expected_structure in
            "dependencies")
                # Check if it's an object with project entries
                if jq -e 'type == "object"' "$file" > /dev/null 2>&1; then
                    local has_valid_structure=$(jq '[.[] | has("dependencies") and has("name")] | all' "$file" 2>/dev/null)
                    if [ "$has_valid_structure" = "true" ]; then
                        return 0
                    fi
                fi
                ;;
            "array")
                if jq -e 'type == "array"' "$file" > /dev/null 2>&1; then
                    return 0
                fi
                ;;
        esac
    fi
    return 1
}

# Function to test repository connectivity
test_repository_connectivity() {
    local test_passed=0
    local total_tests=0
    
    if [ -f "$PROJECT_ROOT/repos.txt" ]; then
        # Test a few repositories from repos.txt
        local test_repos=$(grep -v '^[[:space:]]*$' "$PROJECT_ROOT/repos.txt" 2>/dev/null | grep -v '^#' | head -3)
        
        while IFS= read -r repo_url; do
            if [ -n "$repo_url" ]; then
                total_tests=$((total_tests + 1))
                if [[ "$repo_url" == https://* ]]; then
                    # Test HTTP connectivity
                    if command -v curl &> /dev/null; then
                        if timeout 10 curl -s --head "$repo_url" > /dev/null 2>&1; then
                            test_passed=$((test_passed + 1))
                        fi
                    elif command -v wget &> /dev/null; then
                        if timeout 10 wget --spider -q "$repo_url" 2>/dev/null; then
                            test_passed=$((test_passed + 1))
                        fi
                    fi
                elif [ -d "$repo_url" ]; then
                    # Test local directory access
                    if [ -r "$repo_url" ]; then
                        test_passed=$((test_passed + 1))
                    fi
                fi
            fi
        done <<< "$test_repos"
        
        if [ "$total_tests" -gt 0 ]; then
            if [ "$test_passed" -eq "$total_tests" ]; then
                print_status "pass" "Repository connectivity test passed ($test_passed/$total_tests)"
            elif [ "$test_passed" -gt 0 ]; then
                print_status "warn" "Partial repository connectivity ($test_passed/$total_tests)" "Some repositories may be unreachable"
            else
                print_status "fail" "Repository connectivity test failed ($test_passed/$total_tests)" "Check network connection and repository URLs"
            fi
        fi
    fi
}

# Function to analyze dependency parsing quality
analyze_dependency_parsing_quality() {
    if [ -f "$PROJECT_ROOT/data/dependencies.json" ] && command -v jq &> /dev/null; then
        # Check for common parsing issues
        local projects_with_managed_versions=$(jq '[.[] | .dependencies[] | select(.version == "managed")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        local projects_with_empty_deps=$(jq '[.[] | select(.dependencies == null or (.dependencies | length == 0))] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        local projects_with_unknown_versions=$(jq '[.[] | .dependencies[] | select(.version == "unknown" or .version == "" or .version == null)] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        local total_dependencies=$(jq '[.[] | .dependencies | length] | add // 0' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        
        if [ "$total_dependencies" -gt 0 ]; then
            local managed_percentage=$((projects_with_managed_versions * 100 / total_dependencies))
            local unknown_percentage=$((projects_with_unknown_versions * 100 / total_dependencies))
            
            if [ "$managed_percentage" -gt 50 ]; then
                print_status "info" "High percentage of managed versions detected: ${managed_percentage}%" "This is normal for Spring Boot projects"
            fi
            
            if [ "$unknown_percentage" -gt 20 ]; then
                print_status "warn" "High percentage of unknown versions: ${unknown_percentage}%" "May indicate parsing issues"
            elif [ "$unknown_percentage" -gt 0 ]; then
                print_status "info" "Some dependencies have unknown versions: ${unknown_percentage}%"
            fi
        fi
        
        if [ "$projects_with_empty_deps" -gt 0 ]; then
            print_status "warn" "Found $projects_with_empty_deps projects without dependencies" "May indicate parsing failures"
        fi
        
        # Check for duplicate dependencies within projects
        local projects_with_duplicates=$(jq '[.[] | select(.dependencies | group_by(.group + ":" + .name) | map(length) | map(select(. > 1)) | length > 0)] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        if [ "$projects_with_duplicates" -gt 0 ]; then
            print_status "warn" "Found $projects_with_duplicates projects with duplicate dependencies" "May indicate parsing errors"
        fi
    fi
}

# Function to check module system health
check_module_system_health() {
    local modules_dir="$PROJECT_ROOT/scripts/modules"
    local modules=(
        "common.sh"
        "dependency_parser.sh"
        "json_handler.sh"
        "project_analyzer.sh"
        "repo_manager.sh"
        "version_extractor.sh"
    )
    
    local module_errors=0
    
    for module in "${modules[@]}"; do
        local module_path="$modules_dir/$module"
        
        if [ -f "$module_path" ]; then
            # Basic syntax check
            if bash -n "$module_path" 2>/dev/null; then
                print_status "pass" "Module syntax valid: $module"
            else
                print_status "fail" "Module syntax error: $module"
                module_errors=$((module_errors + 1))
            fi
            
            # Check for required functions (basic check)
            case "$module" in
                "dependency_parser.sh")
                    if grep -q "extract_dependencies\|parse_gradle_dependencies" "$module_path"; then
                        print_status "pass" "Core functions found in $module"
                    else
                        print_status "warn" "Missing expected functions in $module"
                    fi
                    ;;
                "project_analyzer.sh")
                    if grep -q "analyze_project\|is_valid_project" "$module_path"; then
                        print_status "pass" "Core functions found in $module"
                    else
                        print_status "warn" "Missing expected functions in $module"
                    fi
                    ;;
            esac
        else
            print_status "fail" "Missing module: $module"
            module_errors=$((module_errors + 1))
        fi
    done
    
    if [ "$module_errors" -eq 0 ]; then
        print_status "pass" "All modules are healthy"
    else
        print_status "fail" "$module_errors module(s) have issues" "System may not function properly"
    fi
}

# Function to analyze project type distribution
analyze_project_distribution() {
    if [ -f "$PROJECT_ROOT/data/dependencies.json" ] && command -v jq &> /dev/null; then
        # Analyze build systems
        local gradle_projects=$(jq '[.[] | select(.gradleVersion != null and .gradleVersion != "")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        local maven_projects=$(jq '[.[] | select(.dependencies[] | .configuration == "compile" or .configuration == "runtime")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        local total_projects=$(jq '. | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        
        if [ "$total_projects" -gt 0 ]; then
            print_status "info" "Project distribution: $gradle_projects Gradle, $maven_projects Maven (of $total_projects total)"
            
            # Analyze language distribution
            local java_projects=$(jq '[.[] | select(.javaVersion != null and .javaVersion != "")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
            local kotlin_projects=$(jq '[.[] | select(.kotlinVersion != null and .kotlinVersion != "")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
            local spring_projects=$(jq '[.[] | select(.springBootVersion != null and .springBootVersion != "")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
            
            print_status "info" "Technology stack: $java_projects Java, $kotlin_projects Kotlin, $spring_projects Spring Boot"
            
            # Check for potential issues
            if [ "$java_projects" -eq 0 ] && [ "$kotlin_projects" -eq 0 ] && [ "$total_projects" -gt 0 ]; then
                print_status "warn" "No Java/Kotlin versions detected in projects" "Version extraction may have issues"
            fi
        fi
    fi
}

# Function to check web interface functionality
check_web_interface_functionality() {
    # Check if critical web files exist and are properly structured
    local web_files=(
        "$PROJECT_ROOT/index.html"
        "$PROJECT_ROOT/js/app.js"
        "$PROJECT_ROOT/js/adapters/data-adapter.js"
        "$PROJECT_ROOT/css/base.css"
    )
    
    local web_issues=0
    
    for file in "${web_files[@]}"; do
        if [ ! -f "$file" ]; then
            web_issues=$((web_issues + 1))
        fi
    done
    
    if [ "$web_issues" -eq 0 ]; then
        # Test if data adapter can potentially load the dependencies
        if [ -f "$PROJECT_ROOT/data/dependencies.json" ]; then
            # Check if the JSON structure is compatible with the web interface
            if command -v jq &> /dev/null; then
                # Test basic structure that the web interface expects
                local compatible_structure=$(jq -e 'type == "object" and (. | length > 0)' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null)
                if [ "$?" -eq 0 ]; then
                    print_status "pass" "Data structure compatible with web interface"
                else
                    print_status "warn" "Data structure may not be compatible with web interface"
                fi
            fi
        else
            print_status "warn" "No data available for web interface" "Run dependency extraction first"
        fi
        
        # Check for common configuration issues in index.html
        if [ -f "$PROJECT_ROOT/index.html" ]; then
            if grep -q "data/dependencies.json" "$PROJECT_ROOT/index.html"; then
                print_status "pass" "Web interface configured to load dependencies"
            else
                print_status "warn" "Web interface may not be configured to load dependencies"
            fi
        fi
    else
        print_status "fail" "$web_issues critical web files missing" "Web interface will not function"
    fi
}

# Function to check disk space and resource usage
check_system_resources() {
    # Check available disk space in data directory
    if [ -d "$PROJECT_ROOT/data" ]; then
        local available_space=$(df "$PROJECT_ROOT/data" | awk 'NR==2 {print $4}')
        local available_mb=$((available_space / 1024))
        
        if [ "$available_mb" -lt 100 ]; then
            print_status "warn" "Low disk space: ${available_mb}MB available" "Consider cleaning old files"
        elif [ "$available_mb" -lt 1000 ]; then
            print_status "info" "Moderate disk space: ${available_mb}MB available"
        else
            print_status "pass" "Sufficient disk space: ${available_mb}MB available"
        fi
    fi
    
    # Check memory usage (if available)
    if command -v free &> /dev/null; then
        local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        if [ "$available_mem" -lt 512 ]; then
            print_status "warn" "Low available memory: ${available_mem}MB" "May affect large repository processing"
        else
            print_status "pass" "Sufficient memory available: ${available_mem}MB"
        fi
    fi
    
    # Check for zombie processes related to DoneDep
    local zombie_count=$(ps aux | grep -E "(donedep|gradle|maven)" | grep -c "<defunct>" || echo "0")
    if [ "$zombie_count" -gt 0 ]; then
        print_status "warn" "Found $zombie_count zombie processes" "System cleanup may be needed"
    fi
}

# Function to cleanup on exit
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                ${PURPLE}DoneDep Advanced Health Check v3.0${WHITE}                ║${NC}"
echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔍 Performing comprehensive system analysis...${NC}"
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the root directory of the project (one level up from scripts/)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_header "Environment & Dependencies Check"

# Check if jq is available
if command -v jq &> /dev/null; then
    print_status "pass" "jq is available for JSON processing"
else
    print_status "fail" "jq is not installed (required for JSON processing)"
fi

# Check if git is available
if command -v git &> /dev/null; then
    print_status "pass" "git is available"
    
    # Check if we're in a git repository
    if git -C "$PROJECT_ROOT" rev-parse --git-dir &> /dev/null; then
        print_status "pass" "Project is in a git repository"
        
        # Check git status
        if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
            print_status "warn" "There are uncommitted changes in the repository"
        else
            print_status "pass" "Working directory is clean"
        fi
    else
        print_status "warn" "Project is not in a git repository"
    fi
else
    print_status "warn" "git is not available (recommended for repository management)"
fi

# Check if python3 is available for web server
if command -v python3 &> /dev/null; then
    print_status "pass" "python3 is available for web server"
else
    print_status "warn" "python3 is not available (needed for './run.sh view')"
fi

print_header "Project Structure Check"

# Check critical directories
CRITICAL_DIRS=(
    "$PROJECT_ROOT/data"
    "$PROJECT_ROOT/js"
    "$PROJECT_ROOT/css"
    "$PROJECT_ROOT/scripts"
    "$PROJECT_ROOT/scripts/modules"
    "$PROJECT_ROOT/js/core"
    "$PROJECT_ROOT/js/modules"
    "$PROJECT_ROOT/js/adapters"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_status "pass" "Directory exists: $(basename "$dir")"
    else
        print_status "fail" "Missing critical directory: $dir"
    fi
done

# Check critical files
CRITICAL_FILES=(
    "$PROJECT_ROOT/index.html"
    "$PROJECT_ROOT/run.sh"
    "$PROJECT_ROOT/README.md"
    "$PROJECT_ROOT/js/app.js"
    "$PROJECT_ROOT/js/adapters/data-adapter.js"
    "$PROJECT_ROOT/scripts/main.sh"
    "$PROJECT_ROOT/scripts/modules/common.sh"
    "$PROJECT_ROOT/scripts/modules/dependency_parser.sh"
    "$PROJECT_ROOT/scripts/modules/json_handler.sh"
    "$PROJECT_ROOT/scripts/modules/project_analyzer.sh"
    "$PROJECT_ROOT/scripts/modules/repo_manager.sh"
    "$PROJECT_ROOT/scripts/modules/version_extractor.sh"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Check if script files are executable
        if [[ "$file" == *".sh" ]]; then
            if [ -x "$file" ]; then
                print_status "pass" "Script is executable: $(basename "$file")"
            else
                print_status "warn" "Script is not executable: $(basename "$file")"
            fi
        else
            print_status "pass" "File exists: $(basename "$file")"
        fi
    else
        print_status "fail" "Missing critical file: $file"
    fi
done

print_header "Data Files Check"

# Check if dependencies.json exists
if [ -f "$PROJECT_ROOT/data/dependencies.json" ]; then
    print_status "pass" "Main dependencies.json exists"
    
    # Check if it's a symlink
    if [ -L "$PROJECT_ROOT/data/dependencies.json" ]; then
        LINK_TARGET=$(readlink "$PROJECT_ROOT/data/dependencies.json")
        print_status "info" "dependencies.json is a symlink pointing to: $LINK_TARGET"
        
        # Check if symlink target exists
        if [ -f "$PROJECT_ROOT/data/$LINK_TARGET" ]; then
            print_status "pass" "Symlink target exists"
        else
            print_status "fail" "Symlink target does not exist"
        fi
    fi
    
    # Check if the dependencies.json file is valid JSON
    if jq . "$PROJECT_ROOT/data/dependencies.json" > /dev/null 2>&1; then
        print_status "pass" "dependencies.json has valid JSON format"
        
        # Count projects and dependencies
        if command -v jq &> /dev/null; then
            PROJECTS=$(jq '. | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
            DEPS=$(jq '[.[] | .dependencies | length] | add // 0' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
            
            if [ "$PROJECTS" -gt 0 ]; then
                print_status "pass" "Found $PROJECTS projects with $DEPS total dependencies"
                
                # Check for data quality
                PROJECTS_WITH_DEPS=$(jq '[.[] | select(.dependencies | length > 0)] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
                if [ "$PROJECTS_WITH_DEPS" -gt 0 ]; then
                    print_status "pass" "$PROJECTS_WITH_DEPS projects have dependencies"
                else
                    print_status "warn" "No projects have dependencies extracted"
                fi
                
                # Check for version information
                PROJECTS_WITH_JAVA=$(jq '[.[] | select(.javaVersion != null and .javaVersion != "NENHUM")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
                PROJECTS_WITH_SPRING=$(jq '[.[] | select(.springBootVersion != null and .springBootVersion != "NENHUM")] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
                
                print_status "info" "$PROJECTS_WITH_JAVA projects have Java version detected"
                print_status "info" "$PROJECTS_WITH_SPRING projects have Spring Boot version detected"
            else
                print_status "warn" "No projects found in dependencies.json"
            fi
        fi
    else
        print_status "fail" "dependencies.json contains invalid JSON"
    fi
else
    print_status "warn" "dependencies.json not found - run extraction first"
fi

# Check for historical dependency files
HIST_FILES=$(find "$PROJECT_ROOT/data" -name "dependencies_*.json" 2>/dev/null | wc -l)
if [ "$HIST_FILES" -gt 0 ]; then
    print_status "pass" "Found $HIST_FILES historical dependency files"
    
    # Check if dependency-files-list.json exists and is valid
    if [ -f "$PROJECT_ROOT/data/dependency-files-list.json" ]; then
        if jq . "$PROJECT_ROOT/data/dependency-files-list.json" > /dev/null 2>&1; then
            print_status "pass" "dependency-files-list.json is valid"
        else
            print_status "warn" "dependency-files-list.json contains invalid JSON"
        fi
    else
        print_status "warn" "dependency-files-list.json not found"
    fi
else
    print_status "warn" "No historical dependency files found"
fi

# Check log file
if [ -f "$PROJECT_ROOT/data/donedep.log" ]; then
    LOG_SIZE=$(stat -f%z "$PROJECT_ROOT/data/donedep.log" 2>/dev/null || stat -c%s "$PROJECT_ROOT/data/donedep.log" 2>/dev/null || echo "0")
    if [ "$LOG_SIZE" -gt 0 ]; then
        print_status "pass" "Log file exists and has content ($(($LOG_SIZE / 1024))KB)"
        
        # Check for recent errors in log
        if [ -r "$PROJECT_ROOT/data/donedep.log" ]; then
            ERROR_COUNT=$(grep -c "ERROR\|ERRO" "$PROJECT_ROOT/data/donedep.log" 2>/dev/null || echo "0")
            if [ "$ERROR_COUNT" -gt 0 ]; then
                print_status "warn" "Found $ERROR_COUNT errors in log file"
            else
                print_status "pass" "No errors found in log file"
            fi
        fi
    else
        print_status "warn" "Log file exists but is empty"
    fi
else
    print_status "info" "No log file found (will be created on first run)"
fi

print_header "Repository Cache Check"

if [ -d "$PROJECT_ROOT/data/repo_cache" ]; then
    REPO_COUNT=$(find "$PROJECT_ROOT/data/repo_cache" -maxdepth 1 -type d | wc -l)
    REPO_COUNT=$((REPO_COUNT - 1)) # Subtract the repo_cache directory itself
    
    if [ "$REPO_COUNT" -gt 0 ]; then
        print_status "pass" "Repository cache contains $REPO_COUNT repositories"
        
        # Check if repos.txt exists
        if [ -f "$PROJECT_ROOT/repos.txt" ]; then
            REPOS_IN_FILE=$(grep -v '^[[:space:]]*$' "$PROJECT_ROOT/repos.txt" 2>/dev/null | grep -v '^#' | wc -l)
            print_status "info" "repos.txt contains $REPOS_IN_FILE repository entries"
        else
            print_status "warn" "repos.txt not found - repositories must be manually placed in repo_cache"
        fi
    else
        print_status "warn" "Repository cache is empty"
    fi
else
    print_status "warn" "Repository cache directory not found"
fi

print_header "CSS and JavaScript Check"

# Check CSS files
CSS_FILES=(
    "$PROJECT_ROOT/css/base.css"
    "$PROJECT_ROOT/css/dependencies.css"
    "$PROJECT_ROOT/css/filters.css"
    "$PROJECT_ROOT/css/responsive.css"
)

CSS_MISSING=0
for css_file in "${CSS_FILES[@]}"; do
    if [ ! -f "$css_file" ]; then
        CSS_MISSING=$((CSS_MISSING + 1))
    fi
done

if [ "$CSS_MISSING" -eq 0 ]; then
    print_status "pass" "All critical CSS files are present"
else
    print_status "warn" "$CSS_MISSING critical CSS files are missing"
fi

# Check JavaScript modules
JS_MODULES=(
    "$PROJECT_ROOT/js/core"
    "$PROJECT_ROOT/js/modules/dependencies"
    "$PROJECT_ROOT/js/modules/filters"
    "$PROJECT_ROOT/js/modules/projects"
    "$PROJECT_ROOT/js/modules/ui"
)

JS_MISSING=0
for js_dir in "${JS_MODULES[@]}"; do
    if [ ! -d "$js_dir" ]; then
        JS_MISSING=$((JS_MISSING + 1))
    fi
done

if [ "$JS_MISSING" -eq 0 ]; then
    print_status "pass" "All JavaScript module directories are present"
else
    print_status "warn" "$JS_MISSING JavaScript module directories are missing"
fi

print_header "Configuration Check"

# Check for common configuration issues
if [ -f "$PROJECT_ROOT/index.html" ]; then
    # Check if index.html references the correct files
    if grep -q "js/app.js" "$PROJECT_ROOT/index.html"; then
        print_status "pass" "index.html correctly references app.js"
    else
        print_status "warn" "index.html may not reference app.js correctly"
    fi
    
    if grep -q "css/" "$PROJECT_ROOT/index.html"; then
        print_status "pass" "index.html references CSS files"
    else
        print_status "warn" "index.html may not reference CSS files"
    fi
    
    # Check HTML file size and complexity
    check_file_performance "$PROJECT_ROOT/index.html" 1
fi

print_header "Security and Permissions Check"

# Check for sensitive files that shouldn't be committed
SENSITIVE_PATTERNS=(
    "*.log"
    "*.tmp"
    "*_backup*"
    ".env*"
    "config/*.properties"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    found_files=$(find "$PROJECT_ROOT" -name "$pattern" -type f 2>/dev/null | head -5)
    if [ -n "$found_files" ]; then
        count=$(echo "$found_files" | wc -l)
        print_status "warn" "Found potentially sensitive files: $pattern" "Consider adding to .gitignore ($count files)"
    fi
done

# Check .gitignore exists and has common patterns
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    print_status "pass" ".gitignore file exists"
    
    # Check for common ignore patterns
    patterns_to_check=("*.log" "node_modules/" "data/dependencies_*.json" "data/repo_cache/")
    missing_patterns=()
    
    for pattern in "${patterns_to_check[@]}"; do
        if ! grep -q "$pattern" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
            missing_patterns+=("$pattern")
        fi
    done
    
    if [ ${#missing_patterns[@]} -eq 0 ]; then
        print_status "pass" ".gitignore contains recommended patterns"
    else
        print_status "warn" ".gitignore missing patterns: ${missing_patterns[*]}"
    fi
else
    print_status "warn" ".gitignore file not found" "Consider creating one to exclude temporary files"
fi

# Check script permissions
SCRIPTS=(
    "$PROJECT_ROOT/run.sh"
    "$PROJECT_ROOT/scripts/main.sh"
    "$PROJECT_ROOT/scripts/verify.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_status "pass" "Script $(basename "$script") has execute permissions"
        else
            print_status "warn" "Script $(basename "$script") is not executable" "Run: chmod +x $script"
        fi
    fi
done

print_header "Data Quality and Integrity Check"

if [ -f "$PROJECT_ROOT/data/dependencies.json" ] && command -v jq &> /dev/null; then
    # Deep analysis of dependency data
    
    # Check for data consistency
    if validate_json_structure "$PROJECT_ROOT/data/dependencies.json" "dependencies"; then
        print_status "pass" "Dependencies JSON has valid structure"
    else
        print_status "fail" "Dependencies JSON structure is invalid"
    fi
    
    # Analyze dependency parsing quality
    analyze_dependency_parsing_quality
    
    # Analyze project type distribution
    analyze_project_distribution
    
    # Analyze dependency extraction quality
    total_projects=$(jq '. | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
    projects_with_deps=$(jq '[.[] | select(.dependencies | length > 0)] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
    
    if [ "$total_projects" -gt 0 ]; then
        extraction_rate=$(( (projects_with_deps * 100) / total_projects ))
        
        if [ "$extraction_rate" -ge 80 ]; then
            print_status "pass" "High dependency extraction rate: ${extraction_rate}%" "$projects_with_deps/$total_projects projects"
        elif [ "$extraction_rate" -ge 50 ]; then
            print_status "warn" "Moderate dependency extraction rate: ${extraction_rate}%" "$projects_with_deps/$total_projects projects"
        else
            print_status "warn" "Low dependency extraction rate: ${extraction_rate}%" "Consider reviewing extraction process"
        fi
    fi
    
    # Check for configuration type coverage
    config_types=$(jq '[.[] | .dependencies[] | .configType] | unique | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
    if [ "$config_types" -gt 0 ]; then
        print_status "pass" "Found $config_types different configuration types" "Good diversity in project analysis"
    fi
    
    # Check for orphaned or incomplete projects
    incomplete_projects=$(jq '[.[] | select(.name == null or .name == "" or (.dependencies | length == 0 and .buildFile == null))] | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
    if [ "$incomplete_projects" -gt 0 ]; then
        print_status "warn" "Found $incomplete_projects incomplete project entries" "These may need re-processing"
    else
        print_status "pass" "All project entries appear complete"
    fi
    
    # Check file performance
    check_file_performance "$PROJECT_ROOT/data/dependencies.json" 50
fi

print_header "Performance Analysis"

# Check system resources
check_system_resources

# Check data directory size
if [ -d "$PROJECT_ROOT/data" ]; then
    data_size=$(du -sm "$PROJECT_ROOT/data" 2>/dev/null | cut -f1)
    if [ "$data_size" -gt 100 ]; then
        print_status "perf" "Large data directory: ${data_size}MB" "Consider archiving old dependency files"
    else
        print_status "pass" "Data directory size is reasonable: ${data_size}MB"
    fi
fi

# Check repository cache performance
if [ -d "$PROJECT_ROOT/data/repo_cache" ]; then
    cache_size=$(du -sm "$PROJECT_ROOT/data/repo_cache" 2>/dev/null | cut -f1)
    repo_count=$(find "$PROJECT_ROOT/data/repo_cache" -maxdepth 1 -type d | wc -l)
    repo_count=$((repo_count - 1))
    
    if [ "$cache_size" -gt 500 ]; then
        print_status "perf" "Large repository cache: ${cache_size}MB for $repo_count repos" "Consider cleaning old repositories"
    else
        print_status "pass" "Repository cache size is manageable: ${cache_size}MB"
    fi
    
    # Check for Git repositories that may be corrupted
    corrupted_repos=0
    if [ "$repo_count" -gt 0 ]; then
        for repo_dir in "$PROJECT_ROOT/data/repo_cache"/*; do
            if [ -d "$repo_dir" ] && [ -d "$repo_dir/.git" ]; then
                if ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
                    corrupted_repos=$((corrupted_repos + 1))
                fi
            fi
        done
        
        if [ "$corrupted_repos" -gt 0 ]; then
            print_status "warn" "Found $corrupted_repos potentially corrupted Git repositories" "Consider running repository cleanup"
        else
            print_status "pass" "All cached repositories appear healthy"
        fi
    fi
fi

# Check system resource usage during analysis
current_processes=$(pgrep -f "donedep\|java\|gradle\|maven" | wc -l)
if [ "$current_processes" -gt 10 ]; then
    print_status "perf" "High number of related processes running: $current_processes" "System may be under heavy load"
fi

print_header "Development Environment Check"

# Check for development tools
DEV_TOOLS=(
    "java:Java runtime"
    "javac:Java compiler"
    "gradle:Gradle build tool"
    "mvn:Maven build tool"
    "curl:HTTP client for repository cloning"
    "wget:Alternative HTTP client"
)

for tool_info in "${DEV_TOOLS[@]}"; do
    tool_name=$(echo "$tool_info" | cut -d: -f1)
    tool_desc=$(echo "$tool_info" | cut -d: -f2)
    
    if command -v "$tool_name" &> /dev/null; then
        version=$($tool_name --version 2>/dev/null | head -1 | cut -d' ' -f1-3 || echo "version unknown")
        print_status "pass" "$tool_desc is available" "$version"
    else
        if [ "$tool_name" = "java" ] || [ "$tool_name" = "gradle" ]; then
            print_status "warn" "$tool_desc not found" "Required for full functionality"
        else
            print_status "info" "$tool_desc not found" "Optional but recommended"
        fi
    fi
done

# Check Java version compatibility
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | grep "version" | cut -d'"' -f2 | cut -d'.' -f1-2)
    case $java_version in
        "1.8"|"8"|"11"|"17"|"21")
            print_status "pass" "Java version is compatible: $java_version"
            ;;
        *)
            print_status "warn" "Java version may not be optimal: $java_version" "Recommended: 8, 11, 17, or 21"
            ;;
    esac
fi

print_header "Integration and API Check"

# Check repository connectivity
test_repository_connectivity

# Check module system health
check_module_system_health

# Check web interface functionality
check_web_interface_functionality

# Check if the web interface can be started
if [ -f "$PROJECT_ROOT/run.sh" ] && command -v python3 &> /dev/null; then
    # Test if we can bind to the default port
    if command -v netstat &> /dev/null; then
        port_8000_used=$(netstat -ln 2>/dev/null | grep -c ":8000 ")
        if [ "$port_8000_used" -gt 0 ]; then
            print_status "warn" "Port 8000 is already in use" "Web server may not start properly"
        else
            print_status "pass" "Port 8000 is available for web server"
        fi
    fi
fi

# Check if data adapter can load dependencies
if [ -f "$PROJECT_ROOT/js/adapters/data-adapter.js" ] && [ -f "$PROJECT_ROOT/data/dependencies.json" ]; then
    # Simple syntax check for JavaScript
    if command -v node &> /dev/null; then
        if node -c "$PROJECT_ROOT/js/adapters/data-adapter.js" 2>/dev/null; then
            print_status "pass" "Data adapter JavaScript syntax is valid"
        else
            print_status "warn" "Data adapter may have JavaScript syntax errors"
        fi
    fi
fi

print_header "Performance and Health Summary"

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

# Calculate comprehensive health score
TOTAL_ISSUES=$((WARNINGS + ERRORS + PERFORMANCE_ISSUES))
if [ "$CHECKS_TOTAL" -gt 0 ]; then
    HEALTH_SCORE=$(( ((CHECKS_PASSED * 100) / CHECKS_TOTAL) ))
    
    # Adjust score based on error severity
    if [ "$ERRORS" -gt 0 ]; then
        HEALTH_SCORE=$((HEALTH_SCORE - (ERRORS * 10)))
    fi
    if [ "$PERFORMANCE_ISSUES" -gt 0 ]; then
        HEALTH_SCORE=$((HEALTH_SCORE - (PERFORMANCE_ISSUES * 5)))
    fi
    
    # Ensure score doesn't go below 0
    [ "$HEALTH_SCORE" -lt 0 ] && HEALTH_SCORE=0
    
    echo ""
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                      ${CYAN}HEALTH ASSESSMENT${WHITE}                       ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Health score with color and recommendations
    echo -e "${CYAN}Overall Health Score:${NC}"
    if [ "$HEALTH_SCORE" -ge 90 ]; then
        echo -e "  ${GREEN}🟢 $HEALTH_SCORE% - EXCELLENT${NC}"
        system_status="excellent"
    elif [ "$HEALTH_SCORE" -ge 75 ]; then
        echo -e "  ${GREEN}🟡 $HEALTH_SCORE% - GOOD${NC}"
        system_status="good"
    elif [ "$HEALTH_SCORE" -ge 50 ]; then
        echo -e "  ${YELLOW}🟠 $HEALTH_SCORE% - NEEDS ATTENTION${NC}"
        system_status="attention"
    elif [ "$HEALTH_SCORE" -ge 25 ]; then
        echo -e "  ${RED}🔴 $HEALTH_SCORE% - POOR${NC}"
        system_status="poor"
    else
        echo -e "  ${RED}💥 $HEALTH_SCORE% - CRITICAL${NC}"
        system_status="critical"
    fi
    
    echo ""
    echo -e "${CYAN}Detailed Results Summary:${NC}"
    echo -e "  📊 Total Checks Performed: ${WHITE}$CHECKS_TOTAL${NC}"
    echo -e "  ${GREEN}✓ Passed Successfully: $CHECKS_PASSED${NC}"
    
    if [ "$ERRORS" -gt 0 ]; then
        echo -e "  ${RED}🔴 Critical Issues Found: $ERRORS${NC}"
        echo "  ├─ These must be resolved before using DoneDep"
        echo "  └─ Check error messages above for specific issues"
        echo ""
    fi
    
    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "  ${YELLOW}🟡 Warnings: $WARNINGS${NC}"
        echo "  ├─ System will work but may have reduced functionality"
        echo "  └─ Address these for optimal performance"
        echo ""
    fi
    
    if [ "$PERFORMANCE_ISSUES" -gt 0 ]; then
        echo -e "  ${PURPLE}⚡ Performance Issues: $PERFORMANCE_ISSUES${NC}"
        echo "  ├─ May impact processing speed with large datasets"
        echo "  └─ Consider optimization recommendations"
        echo ""
    fi
    
    echo -e "  ⏱️ Analysis Completed in: ${WHITE}${EXECUTION_TIME}s${NC}"
    
    # Add system information
    echo ""
    echo -e "${CYAN}System Environment:${NC}"
    echo "  🖥️  OS: $(uname -s)"
    echo "  🏗️  Architecture: $(uname -m)"
    if command -v bash &> /dev/null; then
        echo "  🐚 Shell: Bash $(bash --version | head -1 | cut -d' ' -f4)"
    fi
    if [ -f "$PROJECT_ROOT/data/dependencies.json" ] && command -v jq &> /dev/null; then
        total_projects=$(jq '. | length' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        total_deps=$(jq '[.[] | .dependencies | length] | add // 0' "$PROJECT_ROOT/data/dependencies.json" 2>/dev/null || echo "0")
        echo "  📦 Projects Analyzed: $total_projects"
        echo "  🔗 Dependencies Tracked: $total_deps"
    fi
    if [ "$ERRORS" -gt 0 ]; then
        echo -e "  ${RED}🔴 Critical Issues Found: $ERRORS${NC}"
        echo "  ├─ These must be resolved before using DoneDep"
        echo "  └─ Check error messages above for specific issues"
        echo ""
    fi
    
    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "  ${YELLOW}🟡 Warnings: $WARNINGS${NC}"
        echo "  ├─ System will work but may have reduced functionality"
        echo "  └─ Address these for optimal performance"
        echo ""
    fi
    
    if [ "$PERFORMANCE_ISSUES" -gt 0 ]; then
        echo -e "  ${PURPLE}⚡ Performance Issues: $PERFORMANCE_ISSUES${NC}"
        echo "  ├─ May impact processing speed with large datasets"
        echo "  └─ Consider optimization recommendations"
        echo ""
    fi
fi

echo ""
echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                     ${CYAN}RECOMMENDATIONS${WHITE}                        ║${NC}"
echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Intelligent recommendations based on findings
if [ "$ERRORS" -eq 0 ]; then
    if [ "$WARNINGS" -eq 0 ] && [ "$PERFORMANCE_ISSUES" -eq 0 ]; then
        echo -e "${GREEN}🎉 DoneDep is fully operational and optimized!${NC}"
        echo ""
        echo -e "${CYAN}Ready to use:${NC}"
        echo "  🚀 Extract dependencies: ${WHITE}./run.sh extract${NC}"
        echo "  🌐 View in browser: ${WHITE}./run.sh view${NC}"
        echo "  🔄 Run full process: ${WHITE}./run.sh${NC}"
    else
        echo -e "${YELLOW}⚠️ DoneDep is operational but could be optimized.${NC}"
        echo ""
        echo -e "${CYAN}Optimization suggestions:${NC}"
        
        if [ "$PERFORMANCE_ISSUES" -gt 0 ]; then
            echo "  🚀 Address performance issues to improve speed"
            echo "  📁 Consider archiving old data files"
            echo "  🧹 Clean repository cache if it's too large"
        fi
        
        if [ "$WARNINGS" -gt 0 ]; then
            echo "  🔧 Review warnings above for system improvements"
            echo "  📝 Update .gitignore to exclude temporary files"
            echo "  🔑 Ensure all scripts have proper permissions"
        fi
    fi
else
    echo -e "${RED}❌ DoneDep has critical issues that must be resolved.${NC}"
    echo ""
    echo -e "${CYAN}Priority actions (in order):${NC}"
    
    # Prioritized recommendations based on error types
    echo "  1️⃣ ${WHITE}Fix critical errors listed above${NC}"
    
    if ! command -v jq &> /dev/null; then
        echo "  2️⃣ ${WHITE}Install jq: sudo apt-get install jq${NC} (Ubuntu/Debian)"
        echo "     ${WHITE}or: brew install jq${NC} (macOS)"
    fi
    
    if [ ! -f "$PROJECT_ROOT/data/dependencies.json" ]; then
        echo "  3️⃣ ${WHITE}Run initial dependency extraction: ./run.sh extract${NC}"
    fi
    
    echo "  4️⃣ ${WHITE}Ensure all required files are present${NC}"
    echo "  5️⃣ ${WHITE}Check project documentation: README.md${NC}"
    echo "  6️⃣ ${WHITE}Re-run verification: ./scripts/verify.sh${NC}"
fi

# System-specific recommendations
echo ""
echo -e "${CYAN}System-specific guidance:${NC}"

case $system_status in
    "excellent")
        echo "  🏆 Consider contributing improvements back to the project"
        echo "  📈 Monitor performance over time as data grows"
        echo "  🔄 Set up automated verification checks"
        ;;
    "good")
        echo "  ✨ Address minor warnings to achieve excellent status"
        echo "  📊 Monitor data extraction quality regularly"
        echo "  🛠️ Consider automation for routine maintenance"
        ;;
    "attention"|"poor")
        echo "  🔍 Focus on resolving errors and warnings systematically"
        echo "  📚 Review documentation for troubleshooting guidance"
        echo "  🧪 Test functionality step by step after each fix"
        ;;
    "critical")
        echo "  🚨 System requires immediate attention before use"
        echo "  📞 Consider seeking help from project maintainers"
        echo "  🔧 Verify installation and dependencies carefully"
        ;;
esac

# Advanced usage suggestions
if [ "$HEALTH_SCORE" -ge 75 ]; then
    echo ""
    echo -e "${CYAN}Advanced features to explore:${NC}"
        echo "  🎯 Use filtering options in the web interface"
    echo "  📋 Export dependency data for external analysis"
    echo "  🔍 Compare dependencies across multiple extractions"
    echo "  ⚙️ Customize configuration types for your projects"
    echo "  📊 Monitor dependency trends over time"
    echo "  🧹 Use ./cleaner.sh to manage data files"

echo ""
echo -e "${CYAN}Maintenance Tips:${NC}"
echo "  🔄 Run verification regularly: ${WHITE}./scripts/verify.sh${NC}"
echo "  📁 Archive old dependency files periodically"
echo "  🔍 Monitor log files for extraction issues"
echo "  🌐 Keep repository URLs updated in repos.txt"
echo "  🔧 Update DoneDep modules when available"

echo ""
echo -e "${CYAN}Troubleshooting Common Issues:${NC}"
echo "  🚫 No dependencies extracted → Check build file formats (gradle/maven)"
echo "  🔗 Repository clone failures → Verify network connectivity and credentials"
echo "  📄 JSON parsing errors → Check for corrupted dependency files"
echo "  🖥️ Web interface not loading → Ensure Python 3 is installed"
echo "  💾 High memory usage → Process fewer repositories at once"
echo "  🐌 Slow performance → Clean repository cache and archive old data"

fi

echo ""
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Health check completed in ${EXECUTION_TIME}s • DoneDep v3.0 Verification${NC}"
echo -e "${GRAY}For more information, visit: README.md${NC}"
echo ""
