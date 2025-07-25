#include <iostream>
#include <vector>
#include <random>
#include <cmath>
#include <algorithm> // For std::clamp

// ====================================================================
// YOUR PROVIDED COLOR CONVERSION CODE
// ====================================================================

struct sRGB {
    double R, G, B; // values in [0, 1]
};

// We add a struct for Linear RGB to make the code clearer
struct LinearRGB {
    double R, G, B; // values in [0, 1] for in-gamut colors
};

struct XYZ {
    double X, Y, Z;
};

struct LAB {
    double L, a, b;
};

// Reference white D65
constexpr double REF_X = 95.047;
constexpr double REF_Y = 100.000;
constexpr double REF_Z = 108.883;

// Linear RGB to sRGB
double toSRGB(double c) {
    return (c <= 0.0031308) ? (12.92 * c) : (1.055 * std::pow(c, 1.0 / 2.4) - 0.055);
}

// Helper for LAB conversion
double f_inv(double t) {
    return (t > 0.206893034) ? (t * t * t) : ((t - 16.0 / 116.0) / 7.787);
}

// CIELAB to XYZ
XYZ LAB_to_XYZ(const LAB& lab) {
    double fy = (lab.L + 16.0) / 116.0;
    double fx = lab.a / 500.0 + fy;
    double fz = fy - lab.b / 200.0;

    XYZ xyz;
    xyz.X = REF_X * f_inv(fx);
    xyz.Y = REF_Y * f_inv(fy);
    xyz.Z = REF_Z * f_inv(fz);

    return xyz;
}

// Convert XYZ to Linear RGB for the gamut check
LinearRGB XYZ_to_LinearRGB(const XYZ& xyz) {
    // This is the linear transformation part from your original XYZ_to_sRGB
    // Note: The XYZ values from the conversion are typically scaled 0-100.
    // We need to scale them to 0-1 before this matrix multiplication.
    double x_norm = xyz.X / 100.0;
    double y_norm = xyz.Y / 100.0;
    double z_norm = xyz.Z / 100.0;

    LinearRGB linear;
    linear.R = x_norm * 3.2404542 + y_norm * -1.5371385 + z_norm * -0.4985314;
    linear.G = x_norm * -0.9692660 + y_norm * 1.8760108 + z_norm * 0.0415560;
    linear.B = x_norm * 0.0556434 + y_norm * -0.2040259 + z_norm * 1.0572252;

    return linear;
}

// ====================================================================
// SAMPLING IMPLEMENTATION
// ====================================================================

// The gamut check function
bool is_in_gamut(const LinearRGB& color) {
    return color.R >= 0.0 && color.R <= 1.0 &&
           color.G >= 0.0 && color.G <= 1.0 &&
           color.B >= 0.0 && color.B <= 1.0;
}


int main() {
    // Use modern C++ for random number generation
    std::random_device rd;
    std::mt19937 gen(rd());

    // Define the distributions for sampling in LAB space
    std::uniform_real_distribution<> dist_L(0.0, 100.0); // L* is [0, 100]
    std::uniform_real_distribution<> dist_ab(-128.0, 127.0); // a* and b* range

    const int num_samples_to_find = 10;
    std::vector<sRGB> valid_colors;
    int total_attempts = 0;

    std::cout << "Searching for " << num_samples_to_find << " in-gamut colors by sampling LAB space...\n\n";

    while (valid_colors.size() < num_samples_to_find) {
        total_attempts++;

        // 1. Pick a random point in CIELAB space
        LAB random_lab = {dist_L(gen), dist_ab(gen), dist_ab(gen)};

        // 2. Convert LAB -> XYZ
        XYZ xyz_color = LAB_to_XYZ(random_lab);

        // 3. Convert XYZ -> Linear RGB
        LinearRGB linear_color = XYZ_to_LinearRGB(xyz_color);

        // 4. THE GAMUT CHECK
        if (is_in_gamut(linear_color)) {
            // 5. If valid, convert to sRGB and store it
            sRGB final_srgb = {
                toSRGB(linear_color.R),
                toSRGB(linear_color.G),
                toSRGB(linear_color.B)
            };
            valid_colors.push_back(final_srgb);

            // Print the 8-bit representation
            std::cout << "Found color " << valid_colors.size() << ": "
                      << "sRGB(" << static_cast<int>(final_srgb.R * 255) << ", "
                      << static_cast<int>(final_srgb.G * 255) << ", "
                      << static_cast<int>(final_srgb.B * 255) << ")\n";
        }
    }

    std::cout << "\nFinished! It took " << total_attempts << " attempts to find " << num_samples_to_find << " valid colors.\n";

    return 0;
}